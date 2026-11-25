export interface FeatureConfig {
  readonly id: string;
  readonly name: string;
  readonly enabled: boolean;
}

export interface FeatureResult<T> {
  readonly success: boolean;
  readonly data?: T;
  readonly error?: string;
}
