const { expect } = require('chai');
const { execSync, spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const {
  ROOT_DIR,
  startStudio,
  stopStudio,
  getEnv
} = require('./helpers');

const PLUGINS_DIR = path.join(ROOT_DIR, 'plugins');
const TEST_PLUGIN_NAME = 'integration-test-plugin';
const TEST_PLUGIN_DIR = path.join(PLUGINS_DIR, TEST_PLUGIN_NAME);
const CONFIG_FILE = path.join(ROOT_DIR, 'config/default.yaml');
const NPM_INSTALL_TEST_PKG = '@norskvideo/norsk-studio-built-ins';

// Load versions to get NORSK_STUDIO_IMAGE
function getStudioImage() {
  const versions = fs.readFileSync(path.join(ROOT_DIR, 'versions'), 'utf8');
  const match = versions.match(/NORSK_STUDIO_IMAGE=(.+)/);
  return match ? match[1] : null;
}

describe('Plugin Workflow', function() {
  this.timeout(600000); // 10 minutes - plugin builds can be slow

  let originalConfig;

  before(function() {
    this.timeout(120000);
    // Update to latest containers
    console.log('Updating to latest containers...');
    execSync('./manage.sh --use-containers studio=latest media=latest', {
      cwd: ROOT_DIR,
      encoding: 'utf8',
      stdio: 'inherit',
      timeout: 60000
    });
    // Save original config
    originalConfig = fs.readFileSync(CONFIG_FILE, 'utf8');
  });

  after(async () => {
    // Restore original config
    fs.writeFileSync(CONFIG_FILE, originalConfig);
    // Clean up test plugin
    if (fs.existsSync(TEST_PLUGIN_DIR)) {
      fs.rmSync(TEST_PLUGIN_DIR, { recursive: true, force: true });
    }
    // Clean up npm-installed plugin
    const npmPluginDir = path.join(PLUGINS_DIR, NPM_INSTALL_TEST_PKG);
    if (fs.existsSync(npmPluginDir)) {
      fs.rmSync(npmPluginDir, { recursive: true, force: true });
    }
    // Stop Studio if running
    try {
      await stopStudio();
    } catch (e) {
      // Ignore if not running
    }
    // Clean up test image
    try {
      execSync('docker rmi norsk-studio:integration-test 2>/dev/null', { cwd: ROOT_DIR });
    } catch (e) {
      // Ignore if doesn't exist
    }
  });

  describe('--install-plugin', function() {
    const installedPluginDir = path.join(PLUGINS_DIR, NPM_INSTALL_TEST_PKG);

    before(() => {
      // Clean up any existing installed plugin
      if (fs.existsSync(installedPluginDir)) {
        fs.rmSync(installedPluginDir, { recursive: true, force: true });
      }
    });

    it('downloads and installs npm package to plugins directory', function() {
      this.timeout(120000);
      const output = execSync(`./manage.sh --install-plugin ${NPM_INSTALL_TEST_PKG}`, {
        cwd: ROOT_DIR,
        encoding: 'utf8',
        timeout: 120000
      });

      expect(fs.existsSync(installedPluginDir)).to.be.true;
      expect(fs.existsSync(path.join(installedPluginDir, 'package.json'))).to.be.true;
    });

    it('installs plugin dependencies', function() {
      // Check node_modules exists (dependencies were installed)
      expect(fs.existsSync(path.join(installedPluginDir, 'node_modules'))).to.be.true;
    });

    it('auto-enables the plugin in config', function() {
      const config = fs.readFileSync(CONFIG_FILE, 'utf8');
      expect(config).to.include(NPM_INSTALL_TEST_PKG);
    });
  });

  describe('--create-plugin', function() {
    before(() => {
      // Clean up any existing test plugin
      if (fs.existsSync(TEST_PLUGIN_DIR)) {
        fs.rmSync(TEST_PLUGIN_DIR, { recursive: true, force: true });
      }
    });

    it('scaffolds a plugin directory', function() {
      const output = execSync(`./manage.sh --create-plugin ${TEST_PLUGIN_NAME}`, {
        cwd: ROOT_DIR,
        encoding: 'utf8',
        timeout: 120000
      });

      expect(fs.existsSync(TEST_PLUGIN_DIR)).to.be.true;
      expect(fs.existsSync(path.join(TEST_PLUGIN_DIR, 'package.json'))).to.be.true;
    });

    it('scaffolds example components', function() {
      expect(fs.existsSync(path.join(TEST_PLUGIN_DIR, 'src/processor.example/runtime.ts'))).to.be.true;
    });
  });

  describe('Plugin build', function() {
    it('npm install succeeds', function() {
      this.timeout(180000);
      execSync('npm install', {
        cwd: TEST_PLUGIN_DIR,
        encoding: 'utf8',
        timeout: 180000
      });
      expect(fs.existsSync(path.join(TEST_PLUGIN_DIR, 'node_modules'))).to.be.true;
    });

    it('npm run build succeeds', function() {
      this.timeout(120000);
      execSync('npm run build', {
        cwd: TEST_PLUGIN_DIR,
        encoding: 'utf8',
        timeout: 120000
      });
      expect(fs.existsSync(path.join(TEST_PLUGIN_DIR, 'lib/index.js'))).to.be.true;
    });

    it('build copies types.yaml files to lib', function() {
      expect(fs.existsSync(path.join(TEST_PLUGIN_DIR, 'lib/processor.example/types.yaml'))).to.be.true;
    });
  });

  describe('link-plugins.sh', function() {
    it('creates symlinks in container', function() {
      const studioImage = getStudioImage();
      const output = execSync(
        `docker run --rm \
          -v "${PLUGINS_DIR}:/usr/src/app/plugins" \
          -v "${ROOT_DIR}/scripts/link-plugins.sh:/usr/src/app/scripts/link-plugins.sh:ro" \
          "${studioImage}" \
          sh -c "/usr/src/app/scripts/link-plugins.sh"`,
        { cwd: ROOT_DIR, encoding: 'utf8', timeout: 60000 }
      );

      expect(output).to.include(`Linked plugin: ${TEST_PLUGIN_NAME}`);
      // Note: scoped package @norskvideo/norsk-studio-built-ins is already in
      // the base image, so it gets skipped (correctly - won't overwrite existing)
    });
  });

  describe('Plugin loading in Studio', function() {
    before(async function() {
      // Enable the plugin
      execSync(`./manage.sh --enable-plugin ${TEST_PLUGIN_NAME}`, {
        cwd: ROOT_DIR,
        encoding: 'utf8'
      });
      // Start Studio
      await startStudio();
    });

    after(async function() {
      await stopStudio();
    });

    it('Studio starts with plugin enabled', async function() {
      const env = await getEnv();
      expect(env).to.be.an('object');
      expect(env.registeredComponents).to.be.an('array');
    });

    it('Studio logs show plugin loaded', function() {
      const logs = execSync('docker logs norsk-studio 2>&1', {
        cwd: ROOT_DIR,
        encoding: 'utf8'
      });
      expect(logs).to.include(TEST_PLUGIN_NAME);
    });

    it('Studio remains running with plugin', function() {
      const status = execSync("docker inspect -f '{{.State.Status}}' norsk-studio", {
        cwd: ROOT_DIR,
        encoding: 'utf8'
      }).trim();
      expect(status).to.equal('running');
    });
  });

  describe('--build-image', function() {
    before(async function() {
      // Stop Studio before building image
      try {
        await stopStudio();
      } catch (e) {
        // Ignore
      }
    });

    it('creates a derived image with plugins', function() {
      this.timeout(300000);
      const output = execSync('./manage.sh --build-image --tag norsk-studio:integration-test', {
        cwd: ROOT_DIR,
        encoding: 'utf8',
        timeout: 300000
      });

      // Check image exists
      const images = execSync('docker images norsk-studio:integration-test --format "{{.Tag}}"', {
        encoding: 'utf8'
      });
      expect(images.trim()).to.equal('integration-test');
    });

    it('built image has plugin installed', function() {
      const output = execSync(
        `docker run --rm norsk-studio:integration-test \
          sh -c "cat /usr/src/app/node_modules/${TEST_PLUGIN_NAME}/package.json"`,
        { encoding: 'utf8', timeout: 30000 }
      );
      expect(output).to.include(`"name": "${TEST_PLUGIN_NAME}"`);
    });
  });
});
