const { expect } = require('chai');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const {
  ROOT_DIR,
  startStudio,
  stopStudio,
  getEnv
} = require('./helpers');

const VERSIONS_FILE = path.join(ROOT_DIR, 'versions');

describe('manage.sh', function() {
  this.timeout(300000); // 5 minutes - container pulls can be slow

  let originalVersions;

  before(() => {
    // Save original versions file
    originalVersions = fs.readFileSync(VERSIONS_FILE, 'utf8');
  });

  after(async () => {
    // Restore original versions file
    fs.writeFileSync(VERSIONS_FILE, originalVersions);
    // Clean up any running containers
    try {
      await stopStudio();
    } catch (e) {
      // Ignore if not running
    }
  });

  describe('--list-containers', function() {
    it('lists available container tags', function() {
      const output = execSync('./manage.sh --list-containers', {
        cwd: ROOT_DIR,
        encoding: 'utf8',
        timeout: 60000
      });

      expect(output).to.include('Norsk Media');
      expect(output).to.include('Norsk Studio');
      // Should list at least some tags
      expect(output).to.match(/\d+\.\d+\.\d+-\d{4}-\d{2}-\d{2}/);
    });
  });

  describe('--use-containers with latest', function() {
    it('resolves latest media container', function() {
      const output = execSync('./manage.sh --use-containers media=latest', {
        cwd: ROOT_DIR,
        encoding: 'utf8',
        timeout: 60000
      });

      expect(output).to.include('Resolved media=latest');
      expect(output).to.include('Updated versions');

      // Verify versions file was updated
      const versions = fs.readFileSync(VERSIONS_FILE, 'utf8');
      expect(versions).to.include('NORSK_MEDIA_IMAGE=');
    });

    it('resolves latest studio container', function() {
      const output = execSync('./manage.sh --use-containers studio=latest', {
        cwd: ROOT_DIR,
        encoding: 'utf8',
        timeout: 60000
      });

      expect(output).to.include('Resolved studio=latest');
      expect(output).to.include('Updated versions');

      // Verify versions file was updated
      const versions = fs.readFileSync(VERSIONS_FILE, 'utf8');
      expect(versions).to.include('NORSK_STUDIO_IMAGE=');
    });

    it('resolves both latest containers', function() {
      const output = execSync('./manage.sh --use-containers media=latest studio=latest', {
        cwd: ROOT_DIR,
        encoding: 'utf8',
        timeout: 60000
      });

      expect(output).to.include('Resolved media=latest');
      expect(output).to.include('Resolved studio=latest');

      // Verify versions file has both
      const versions = fs.readFileSync(VERSIONS_FILE, 'utf8');
      expect(versions).to.include('NORSK_MEDIA_IMAGE=');
      expect(versions).to.include('NORSK_STUDIO_IMAGE=');
    });
  });

  describe('containers start with latest versions', function() {
    before(async function() {
      // Switch to latest containers
      execSync('./manage.sh --use-containers media=latest studio=latest', {
        cwd: ROOT_DIR,
        encoding: 'utf8',
        timeout: 60000
      });
      // Start Studio once for all tests in this block
      await startStudio();
    });

    after(async function() {
      await stopStudio();
    });

    it('containers are running', function() {
      const containers = execSync('docker ps --format "{{.Names}}"').toString();
      expect(containers).to.include('norsk-media');
      expect(containers).to.include('norsk-studio');
    });

    it('Studio responds to requests', async function() {
      const env = await getEnv();
      expect(env).to.be.an('object');
      expect(env.registeredComponents).to.be.an('array');
    });
  });
});
