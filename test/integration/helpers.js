const { execSync } = require('child_process');
const path = require('path');

// __dirname is test/integration, so go up two levels to repo root
const ROOT_DIR = path.resolve(__dirname, '../..');

// Cache the URL once resolved
let _studioUrl = null;

function getStudioUrl() {
  if (_studioUrl) return _studioUrl;

  if (process.env.STUDIO_URL) {
    _studioUrl = process.env.STUDIO_URL;
    return _studioUrl;
  }

  // In CI, look up container IP since localhost might not work
  if (process.env.CI) {
    try {
      const ip = execSync(
        "docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' norsk-studio",
        { encoding: 'utf8' }
      ).trim();
      if (ip) {
        console.log(`Using container IP: ${ip}`);
        _studioUrl = `http://${ip}:8000`;
        return _studioUrl;
      }
    } catch (e) {
      // Container might not be running yet, fall back to localhost
    }
  }

  _studioUrl = 'http://localhost:8000';
  return _studioUrl;
}

// Reset cached URL (call after stopping containers)
function resetStudioUrl() {
  _studioUrl = null;
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function waitForHealthy(maxAttempts = 60) {
  console.log(`Waiting for Studio to become healthy (max ${maxAttempts}s)...`);

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      const res = await fetch(`${getStudioUrl()}/env`);
      if (res.ok) {
        console.log(`Studio healthy after ${attempt}s`);
        return;
      }
    } catch (e) {
      // Not ready yet
    }
    await sleep(1000);
  }

  // Dump logs for debugging
  console.error('Studio did not become healthy. Container logs:');
  try {
    console.error('--- norsk-studio logs ---');
    console.error(execSync('docker logs norsk-studio 2>&1 | tail -50').toString());
    console.error('--- norsk-media logs ---');
    console.error(execSync('docker logs norsk-media 2>&1 | tail -50').toString());
  } catch (e) { /* ignore */ }

  throw new Error(`Studio not healthy after ${maxAttempts}s`);
}

async function waitForWorkflowRunning(maxAttempts = 60) {
  console.log(`Waiting for workflow to be running (max ${maxAttempts}s)...`);

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      const res = await fetch(`${getStudioUrl()}/live/api/components`);
      if (res.ok) {
        const data = await res.json();
        if (data.components && data.components.length > 0) {
          console.log(`Workflow running with ${data.totalComponents} components after ${attempt}s`);
          return;
        }
      }
    } catch (e) {
      // Not ready yet
    }
    await sleep(1000);
  }

  throw new Error(`Workflow not running after ${maxAttempts}s`);
}

async function startStudio(args = '') {
  // Force docker networking mode in CI - host mode doesn't work in GHA runners
  const networkMode = process.env.CI ? '--network-mode docker' : '';
  const cmd = `./up.sh ${networkMode} ${args}`.trim().replace(/\s+/g, ' ');
  console.log(`Starting: ${cmd} (in ${ROOT_DIR})`);
  try {
    execSync(cmd, { stdio: 'inherit', cwd: ROOT_DIR });
  } catch (e) {
    // Dump container logs on startup failure
    console.error('=== Startup failed, dumping container logs ===');
    try {
      console.error('--- norsk-media logs ---');
      console.error(execSync('docker logs norsk-media 2>&1').toString());
    } catch (_) { /* ignore */ }
    try {
      console.error('--- norsk-studio logs ---');
      console.error(execSync('docker logs norsk-studio 2>&1').toString());
    } catch (_) { /* ignore */ }
    throw e;
  }
  await waitForHealthy();
}

async function stopStudio() {
  console.log('Stopping Studio...');
  execSync('./down.sh', { stdio: 'inherit', cwd: ROOT_DIR });
  resetStudioUrl();
}

async function startSrtSource(name) {
  console.log(`Starting SRT source: ${name}`);
  execSync(`./sample-srt-source.sh ${name} start`, {
    stdio: 'inherit',
    cwd: ROOT_DIR
  });
}

async function stopSrtSource(name) {
  console.log(`Stopping SRT source: ${name}`);
  try {
    execSync(`./sample-srt-source.sh ${name} stop`, {
      stdio: 'inherit',
      cwd: ROOT_DIR
    });
  } catch (e) {
    // Ignore errors on stop
  }
}

async function getEnv() {
  const res = await fetch(`${getStudioUrl()}/env`);
  if (!res.ok) throw new Error(`Failed to get /env: ${res.status}`);
  return res.json();
}

async function getLiveComponents() {
  const res = await fetch(`${getStudioUrl()}/live/api/components`);
  if (!res.ok) {
    if (res.status === 503) {
      const err = await res.json();
      throw new Error(`Workflow not running: ${err.error}`);
    }
    throw new Error(`Failed to get components: ${res.status}`);
  }
  return res.json();
}

async function getComponentState(componentId, retries = 5) {
  for (let attempt = 0; attempt < retries; attempt++) {
    const res = await fetch(`${getStudioUrl()}/live/api/${componentId}/state`);
    if (res.ok) {
      return res.json();
    }
    if (res.status === 503 && attempt < retries - 1) {
      // Service not ready yet, wait and retry
      await sleep(1000);
      continue;
    }
    throw new Error(`Failed to get state for ${componentId}: ${res.status}`);
  }
}

async function getComponentById(componentId) {
  const data = await getLiveComponents();
  const component = data.components.find(c => c.componentId === componentId);
  if (component) {
    // Fetch the state separately
    component.state = await getComponentState(componentId);
  }
  return component;
}

async function waitForSrtConnection(componentId, streamId, maxAttempts = 30) {
  console.log(`Waiting for SRT connection: ${componentId}/${streamId}...`);

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      const state = await getComponentState(componentId);
      if (state?.connectedStreams?.includes(streamId)) {
        console.log(`SRT stream ${streamId} connected after ${attempt}s`);
        return { componentId, state };
      }
    } catch (e) {
      // Not ready yet
    }
    await sleep(1000);
  }

  throw new Error(`SRT stream ${streamId} not connected after ${maxAttempts}s`);
}

module.exports = {
  getStudioUrl,
  ROOT_DIR,
  sleep,
  waitForHealthy,
  waitForWorkflowRunning,
  startStudio,
  stopStudio,
  startSrtSource,
  stopSrtSource,
  getEnv,
  getLiveComponents,
  getComponentState,
  getComponentById,
  waitForSrtConnection
};
