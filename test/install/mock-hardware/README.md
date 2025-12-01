# Hardware Profile Mocks

Mocked hardware profiles for testing without actual hardware.

## Usage

Replace actual hardware scripts with mocks for testing:

```bash
# Test quadra profile without hardware
cp test/install/mock-hardware/quadra.sh scripts/hardware/quadra.sh

# Run bootstrap with mocked quadra
./scripts/bootstrap.sh --hardware=quadra --license=test --password=test
```

## Mock Profiles

- `quadra.sh` - Simulates Quadra setup (skips downloads/builds)
- `nvidia.sh` - Simulates NVIDIA setup (for future testing)

Mocks log actions instead of executing them, allowing dry-run testing.
