;; Asset Allocation Contract
;; Manages distribution across chains

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INSUFFICIENT_BALANCE (err u401))
(define-constant ERR_INVALID_ALLOCATION (err u402))
(define-constant ERR_USER_NOT_FOUND (err u403))

;; User portfolio structure
(define-map user-portfolios
  { user: principal }
  {
    total-value: uint,
    last-rebalanced: uint,
    risk-tolerance: uint
  }
)

;; Asset allocations per user
(define-map user-allocations
  { user: principal, protocol-id: (string-ascii 64), asset: (string-ascii 32) }
  {
    amount: uint,
    percentage: uint,
    allocated-at: uint
  }
)

;; Allocation strategies
(define-map allocation-strategies
  { strategy-id: (string-ascii 32) }
  {
    name: (string-ascii 128),
    max-risk: uint,
    min-diversification: uint,
    rebalance-threshold: uint
  }
)

;; Initialize user portfolio
(define-public (initialize-portfolio (risk-tolerance uint))
  (begin
    (asserts! (<= risk-tolerance u100) ERR_INVALID_ALLOCATION)
    (map-set user-portfolios
      { user: tx-sender }
      {
        total-value: u0,
        last-rebalanced: block-height,
        risk-tolerance: risk-tolerance
      }
    )
    (ok true)
  )
)

;; Allocate assets to protocol
(define-public (allocate-assets (protocol-id (string-ascii 64))
                               (asset (string-ascii 32))
                               (amount uint)
                               (percentage uint))
  (begin
    (asserts! (<= percentage u100) ERR_INVALID_ALLOCATION)
    (asserts! (> amount u0) ERR_INVALID_ALLOCATION)

    (match (map-get? user-portfolios { user: tx-sender })
      portfolio
      (begin
        (map-set user-allocations
          { user: tx-sender, protocol-id: protocol-id, asset: asset }
          {
            amount: amount,
            percentage: percentage,
            allocated-at: block-height
          }
        )
        (map-set user-portfolios
          { user: tx-sender }
          (merge portfolio {
            total-value: (+ (get total-value portfolio) amount)
          })
        )
        (ok true)
      )
      ERR_USER_NOT_FOUND
    )
  )
)

;; Rebalance portfolio
(define-public (rebalance-portfolio)
  (match (map-get? user-portfolios { user: tx-sender })
    portfolio
    (begin
      (map-set user-portfolios
        { user: tx-sender }
        (merge portfolio {
          last-rebalanced: block-height
        })
      )
      (ok true)
    )
    ERR_USER_NOT_FOUND
  )
)

;; Get user portfolio
(define-read-only (get-portfolio (user principal))
  (map-get? user-portfolios { user: user })
)

;; Get user allocation
(define-read-only (get-allocation (user principal)
                                 (protocol-id (string-ascii 64))
                                 (asset (string-ascii 32)))
  (map-get? user-allocations { user: user, protocol-id: protocol-id, asset: asset })
)
