import test from 'node:test';
import assert from 'node:assert/strict';
import { FeatureModule } from './feature.js';

test('FeatureModule executes when enabled', () => {
  const mod = new FeatureModule({ id: 'f1', name: 'Sample', enabled: true });
  const res = mod.execute({ value: 42 });
  assert.equal(res.success, true);
  assert.deepEqual(res.data, { value: 42 });
});

test('FeatureModule returns error when disabled', () => {
  const mod = new FeatureModule({ id: 'f2', name: 'Disabled', enabled: false });
  const res = mod.execute({ value: 42 });
  assert.equal(res.success, false);
  assert.equal(res.error, 'Feature disabled');
});
