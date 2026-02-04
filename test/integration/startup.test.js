const { expect } = require('chai');
const { execSync } = require('child_process');
const { startStudio, stopStudio, getEnv } = require('./helpers');

describe('Container Startup', function() {
  this.timeout(120000);

  after(async () => {
    await stopStudio();
  });

  it('starts containers via up.sh', async () => {
    await startStudio();

    // Verify containers are running
    const containers = execSync('docker ps --format "{{.Names}}"').toString();
    expect(containers).to.include('norsk-media');
    expect(containers).to.include('norsk-studio');
  });

  it('Studio responds to requests', async () => {
    const env = await getEnv();
    expect(env).to.be.an('object');
    expect(env.registeredComponents).to.be.an('array');
  });
});
