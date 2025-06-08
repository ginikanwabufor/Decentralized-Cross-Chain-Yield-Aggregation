;; Yield Comparison Contract
;; Analyzes returns across protocols

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_YIELD_NOT_FOUND (err u301))
(define-constant ERR_INVALID_YIELD (err u302))

;; Yield data structure
(define-map yield-data
  { protocol-id: (string-ascii 64), asset: (string-ascii 32) }
  {
    apy: uint,
    tvl: uint,
    last-updated: uint,
    risk-level: uint
  }
)

;; Best yields tracking
(define-map best-yields
  { asset: (string-ascii 32) }
  {
    protocol-id: (string-ascii 64),
    apy: uint,
    updated-at: uint
  }
)

;; Update yield data
(define-public (update-yield (protocol-id (string-ascii 64))
                           (asset (string-ascii 32))
                           (apy uint)
                           (tvl uint)
                           (risk-level uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= apy u10000) ERR_INVALID_YIELD) ;; Max 100% APY (in basis points)
    (asserts! (<= risk-level u100) ERR_INVALID_YIELD)

    (map-set yield-data
      { protocol-id: protocol-id, asset: asset }
      {
        apy: apy,
        tvl: tvl,
        last-updated: block-height,
        risk-level: risk-level
      }
    )

    ;; Update best yield if this is better
    (match (map-get? best-yields { asset: asset })
      current-best
      (if (> apy (get apy current-best))
        (map-set best-yields
          { asset: asset }
          {
            protocol-id: protocol-id,
            apy: apy,
            updated-at: block-height
          }
        )
        true
      )
      ;; First entry for this asset
      (map-set best-yields
        { asset: asset }
        {
          protocol-id: protocol-id,
          apy: apy,
          updated-at: block-height
        }
      )
    )
    (ok true)
  )
)

;; Get yield data
(define-read-only (get-yield (protocol-id (string-ascii 64)) (asset (string-ascii 32)))
  (map-get? yield-data { protocol-id: protocol-id, asset: asset })
)

;; Get best yield for asset
(define-read-only (get-best-yield (asset (string-ascii 32)))
  (map-get? best-yields { asset: asset })
)

;; Compare yields between protocols
(define-read-only (compare-yields (protocol1 (string-ascii 64))
                                 (protocol2 (string-ascii 64))
                                 (asset (string-ascii 32)))
  (match (map-get? yield-data { protocol-id: protocol1, asset: asset })
    yield1
    (match (map-get? yield-data { protocol-id: protocol2, asset: asset })
      yield2
      (some {
        protocol1-apy: (get apy yield1),
        protocol2-apy: (get apy yield2),
        difference: (if (> (get apy yield1) (get apy yield2))
                      (- (get apy yield1) (get apy yield2))
                      (- (get apy yield2) (get apy yield1)))
      })
      none
    )
    none
  )
)
