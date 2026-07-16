/**
 * Classifies every user-initiated on-chain action indexed by the backend.
 * The string values are persisted in Postgres — never change them.
 */
export enum TransactionType {
  /** Purchasing tokens during a Live sale via LaunchProject.buy(). */
  Buy = 'buy',

  /** Selling purchased tokens back during a Live sale via LaunchProject.sell(). */
  Sell = 'sell',

  /** Deploying a new token and launch project via SherwoodFactory.createLaunch(). */
  Create = 'create',

  /** Claiming purchased tokens after graduation via LaunchProject.claim(). */
  Claim = 'claim',

  /** Receiving a native-asset refund after cancellation via LaunchProject.claim(). */
  Refund = 'refund',
}
