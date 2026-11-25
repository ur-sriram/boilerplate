import type { FeatureConfig, FeatureResult } from './feature.types.js';

export class FeatureModule {
  private readonly config: FeatureConfig;

  constructor(config: FeatureConfig) {
    this.config = config;
  }

  public execute<T>(input: T): FeatureResult<T> {
    if (!this.config.enabled) {
      return { success: false, error: 'Feature disabled' };
    }
    return { success: true, data: input };
  }
}
