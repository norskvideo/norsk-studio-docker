const { expect } = require('chai');
const {
  startStudio,
  stopStudio,
  startSrtSource,
  stopSrtSource,
  waitForWorkflowRunning,
  getComponentState,
  waitForSrtConnection,
  sleep
} = require('./helpers');

describe('SRT Sources', function() {
  this.timeout(180000);

  before(async () => {
    // Use Source Switcher workflow which accepts both camera1 and camera2
    await startStudio('--workflow 06-Source-Switcher-to-HLS-Ladder.yaml');
    await waitForWorkflowRunning();
  });

  after(async () => {
    await stopSrtSource('camera1');
    await stopSrtSource('camera2');
    await stopStudio();
  });

  it('camera1 connects to SRT input', async () => {
    await startSrtSource('camera1');
    const result = await waitForSrtConnection('srt_input', 'camera1', 30);
    expect(result.state.connectedStreams).to.include('camera1');
  });

  it('camera2 connects to SRT input', async () => {
    await startSrtSource('camera2');
    const result = await waitForSrtConnection('srt_input', 'camera2', 30);
    expect(result.state.connectedStreams).to.include('camera2');
  });

  it('both sources connected simultaneously', async () => {
    // Both should still be connected from previous tests
    const state = await getComponentState('srt_input');
    expect(state.connectedStreams).to.include('camera1');
    expect(state.connectedStreams).to.include('camera2');
  });

  it('camera1 disconnects cleanly', async () => {
    await stopSrtSource('camera1');

    // Wait for disconnect
    for (let i = 0; i < 15; i++) {
      const state = await getComponentState('srt_input');
      if (!state.connectedStreams.includes('camera1')) {
        // camera2 should still be connected
        expect(state.connectedStreams).to.include('camera2');
        return;
      }
      await sleep(1000);
    }

    const state = await getComponentState('srt_input');
    expect(state.connectedStreams).to.not.include('camera1');
    expect(state.connectedStreams).to.include('camera2');
  });

  it('camera2 disconnects cleanly', async () => {
    await stopSrtSource('camera2');

    // Wait for disconnect
    for (let i = 0; i < 15; i++) {
      const state = await getComponentState('srt_input');
      if (!state.connectedStreams.includes('camera2')) {
        return;
      }
      await sleep(1000);
    }

    const state = await getComponentState('srt_input');
    expect(state.connectedStreams).to.not.include('camera2');
  });
});
