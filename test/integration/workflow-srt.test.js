const { expect } = require('chai');
const {
  startStudio,
  stopStudio,
  startSrtSource,
  stopSrtSource,
  waitForWorkflowRunning,
  getLiveComponents,
  getComponentById,
  waitForSrtConnection,
  sleep
} = require('./helpers');

describe('Workflow with SRT Source', function() {
  this.timeout(180000);

  before(async () => {
    await startStudio('--workflow 01-SRT-to-HLS-Ladder.yaml');
    await waitForWorkflowRunning();
  });

  after(async () => {
    await stopSrtSource('camera1');
    await stopStudio();
  });

  it('--workflow flag loads the workflow', async () => {
    const data = await getLiveComponents();
    expect(data.totalComponents).to.equal(3);
  });

  it('sample-srt-source.sh connects to SRT input', async () => {
    // Verify source not connected initially
    let srtInput = await getComponentById('srt_input');
    expect(srtInput.state.connectedStreams).to.not.include('camera1');

    // Start source
    await startSrtSource('camera1');

    // Wait for connection
    srtInput = await waitForSrtConnection('srt_input', 'camera1', 30);
    expect(srtInput.state.connectedStreams).to.include('camera1');
  });

  it('sample-srt-source.sh stop disconnects', async () => {
    await stopSrtSource('camera1');

    // Wait for disconnect (poll until disconnected or timeout)
    for (let i = 0; i < 15; i++) {
      const srtInput = await getComponentById('srt_input');
      if (!srtInput.state.connectedStreams.includes('camera1')) {
        return; // Success
      }
      await sleep(1000);
    }

    // Final check
    const srtInput = await getComponentById('srt_input');
    expect(srtInput.state.connectedStreams).to.not.include('camera1');
  });
});
