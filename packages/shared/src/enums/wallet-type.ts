/**
 * Connection mechanism used to link a wallet to the SHERWOOD frontend.
 * Used for analytics and UX personalisation — not stored on-chain.
 * The string values are persisted in Postgres — never change them.
 */
export enum WalletType {
  /** Browser-injected provider (MetaMask, Rabby, Frame, etc.). */
  Injected = 'injected',

  /** WalletConnect v2 QR / deeplink pairing. */
  WalletConnect = 'wallet_connect',

  /** Coinbase Smart Wallet / Coinbase Wallet SDK. */
  Coinbase = 'coinbase',
}
