;; Escrow Manager Smart Contract
;; Manages donation escrows and verification-based fund release for homeless shelters

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_ESCROW_NOT_FOUND (err u201))
(define-constant ERR_INVALID_AMOUNT (err u202))
(define-constant ERR_INVALID_STATUS (err u203))
(define-constant ERR_SHELTER_NOT_VERIFIED (err u204))
(define-constant ERR_INSUFFICIENT_BALANCE (err u205))
(define-constant ERR_ALREADY_VERIFIED (err u206))
(define-constant ERR_ESCROW_EXPIRED (err u207))
(define-constant ERR_INVALID_BENEFICIARY_COUNT (err u208))
(define-constant ERR_DISPUTE_PERIOD_ACTIVE (err u209))

;; Escrow status constants
(define-constant STATUS_ACTIVE u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_COMPLETED u2)
(define-constant STATUS_DISPUTED u3)
(define-constant STATUS_REFUNDED u4)
(define-constant STATUS_EXPIRED u5)

;; Service verification constants
(define-constant MIN_BENEFICIARY_COUNT u1)
(define-constant MAX_BENEFICIARY_COUNT u1000)
(define-constant DEFAULT_ESCROW_DURATION u4320) ;; ~30 days in blocks
(define-constant DISPUTE_PERIOD u1440) ;; ~10 days in blocks
(define-constant MIN_DONATION_AMOUNT u100000) ;; 0.1 STX

;; Platform fee (2%)
(define-constant PLATFORM_FEE_BASIS_POINTS u200)
(define-constant BASIS_POINTS_DIVISOR u10000)

;; Data Variables
(define-data-var next-escrow-id uint u1)
(define-data-var contract-owner principal tx-sender)
(define-data-var total-escrows uint u0)
(define-data-var total-completed-escrows uint u0)
(define-data-var total-donations uint u0)
(define-data-var platform-fee-collected uint u0)
(define-data-var dispute-resolution-active bool true)

;; Data Maps

;; Main escrow records
(define-map escrows uint {
  donor: principal,
  shelter: principal,
  amount: uint,
  platform-fee: uint,
  status: uint,
  creation-block: uint,
  expiration-block: uint,
  completion-block: uint,
  service-description: (string-ascii 500),
  required-beneficiaries: uint,
  verified-beneficiaries: uint,
  verification-deadline: uint
})

;; Service verification records
(define-map service-verifications { escrow-id: uint, verifier: principal } {
  verification-block: uint,
  beneficiaries-served: uint,
  service-evidence: (string-ascii 500),
  verification-hash: (string-ascii 64),
  verified: bool
})

;; Authorized verifiers for care verification
(define-map authorized-verifiers principal {
  is-authorized: bool,
  verification-count: uint,
  reputation-score: uint,
  last-verification-block: uint
})

;; Dispute records
(define-map disputes uint {
  escrow-id: uint,
  disputer: principal,
  dispute-reason: (string-ascii 300),
  dispute-block: uint,
  resolution-block: uint,
  resolved: bool,
  resolution-in-favor-of-donor: bool
})

;; Donor donation history
(define-map donor-history principal {
  total-donated: uint,
  total-escrows: uint,
  successful-escrows: uint,
  disputed-escrows: uint,
  reputation-score: uint
})

;; Monthly platform statistics
(define-map monthly-platform-stats { year: uint, month: uint } {
  total-donations: uint,
  total-escrows: uint,
  completed-escrows: uint,
  people-served: uint,
  platform-fees: uint
})

;; Escrow milestones (for multi-stage releases)
(define-map escrow-milestones { escrow-id: uint, milestone: uint } {
  description: (string-ascii 200),
  amount: uint,
  completed: bool,
  completion-block: uint,
  verifier: (optional principal)
})

;; Administrative functions

;; Set new contract owner
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Toggle dispute resolution system
(define-public (toggle-dispute-resolution (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set dispute-resolution-active enabled)
    (ok true)
  )
)

;; Add authorized verifier
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set authorized-verifiers verifier {
      is-authorized: true,
      verification-count: u0,
      reputation-score: u100,
      last-verification-block: u0
    })
    (ok true)
  )
)

;; Remove authorized verifier
(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set authorized-verifiers verifier {
      is-authorized: false,
      verification-count: u0,
      reputation-score: u0,
      last-verification-block: u0
    })
    (ok true)
  )
)

;; Core escrow functions

;; Create new donation escrow
(define-public (create-escrow 
  (shelter principal)
  (amount uint)
  (service-description (string-ascii 500))
  (required-beneficiaries uint)
  (duration-blocks uint)
)
  (let (
    (escrow-id (var-get next-escrow-id))
    (platform-fee (/ (* amount PLATFORM_FEE_BASIS_POINTS) BASIS_POINTS_DIVISOR))
    (total-amount (+ amount platform-fee))
    (expiration-block (+ stacks-block-height (if (> duration-blocks DEFAULT_ESCROW_DURATION) duration-blocks DEFAULT_ESCROW_DURATION)))
  )
    ;; Validate inputs
    (asserts! (>= amount MIN_DONATION_AMOUNT) ERR_INVALID_AMOUNT)
    (asserts! (>= required-beneficiaries MIN_BENEFICIARY_COUNT) ERR_INVALID_BENEFICIARY_COUNT)
    (asserts! (<= required-beneficiaries MAX_BENEFICIARY_COUNT) ERR_INVALID_BENEFICIARY_COUNT)
    
    ;; Verify shelter is registered and verified (simplified - in real implementation would call shelter registry)
    ;; For this standalone version, we'll assume shelter verification is handled externally
    
    ;; Transfer funds to escrow (contract holds the funds)
    (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))
    
    ;; Create escrow record
    (map-set escrows escrow-id {
      donor: tx-sender,
      shelter: shelter,
      amount: amount,
      platform-fee: platform-fee,
      status: STATUS_ACTIVE,
      creation-block: stacks-block-height,
      expiration-block: expiration-block,
      completion-block: u0,
      service-description: service-description,
      required-beneficiaries: required-beneficiaries,
      verified-beneficiaries: u0,
      verification-deadline: (- expiration-block DISPUTE_PERIOD)
    })
    
    ;; Update donor history
    (let (
      (donor-stats (default-to {
        total-donated: u0,
        total-escrows: u0,
        successful-escrows: u0,
        disputed-escrows: u0,
        reputation-score: u100
      } (map-get? donor-history tx-sender)))
    )
      (map-set donor-history tx-sender {
        total-donated: (+ (get total-donated donor-stats) amount),
        total-escrows: (+ (get total-escrows donor-stats) u1),
        successful-escrows: (get successful-escrows donor-stats),
        disputed-escrows: (get disputed-escrows donor-stats),
        reputation-score: (get reputation-score donor-stats)
      })
    )
    
    ;; Update global statistics
    (var-set next-escrow-id (+ escrow-id u1))
    (var-set total-escrows (+ (var-get total-escrows) u1))
    (var-set total-donations (+ (var-get total-donations) amount))
    (var-set platform-fee-collected (+ (var-get platform-fee-collected) platform-fee))
    
    (ok escrow-id)
  )
)

;; Verify care delivery and release funds
(define-public (verify-care 
  (escrow-id uint)
  (beneficiaries-served uint)
  (service-evidence (string-ascii 500))
  (verification-hash (string-ascii 64))
)
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR_ESCROW_NOT_FOUND))
    (verifier-data (unwrap! (map-get? authorized-verifiers tx-sender) ERR_UNAUTHORIZED))
  )
    ;; Validate verifier authorization
    (asserts! (get is-authorized verifier-data) ERR_UNAUTHORIZED)
    
    ;; Validate escrow status and timing
    (asserts! (is-eq (get status escrow) STATUS_ACTIVE) ERR_INVALID_STATUS)
    (asserts! (<= stacks-block-height (get verification-deadline escrow)) ERR_ESCROW_EXPIRED)
    
    ;; Validate service delivery
    (asserts! (>= beneficiaries-served (get required-beneficiaries escrow)) ERR_INVALID_BENEFICIARY_COUNT)
    
    ;; Check if already verified by this verifier
    (asserts! (is-none (map-get? service-verifications { escrow-id: escrow-id, verifier: tx-sender })) ERR_ALREADY_VERIFIED)
    
    ;; Record verification
    (map-set service-verifications { escrow-id: escrow-id, verifier: tx-sender } {
      verification-block: stacks-block-height,
      beneficiaries-served: beneficiaries-served,
      service-evidence: service-evidence,
      verification-hash: verification-hash,
      verified: true
    })
    
    ;; Update escrow status
    (map-set escrows escrow-id (merge escrow {
      status: STATUS_VERIFIED,
      verified-beneficiaries: beneficiaries-served,
      completion-block: stacks-block-height
    }))
    
    ;; Release funds to shelter
    (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get shelter escrow))))
    
    ;; Update verifier statistics
    (map-set authorized-verifiers tx-sender {
      is-authorized: true,
      verification-count: (+ (get verification-count verifier-data) u1),
      reputation-score: (if (< (get reputation-score verifier-data) u99) (+ (get reputation-score verifier-data) u1) u100),
      last-verification-block: stacks-block-height
    })
    
    ;; Update completion statistics
    (var-set total-completed-escrows (+ (var-get total-completed-escrows) u1))
    
    ;; Update donor success count
    (let (
      (donor-stats (unwrap! (map-get? donor-history (get donor escrow)) ERR_UNAUTHORIZED))
    )
      (map-set donor-history (get donor escrow) (merge donor-stats {
        successful-escrows: (+ (get successful-escrows donor-stats) u1)
      }))
    )
    
    (ok true)
  )
)

;; Initiate dispute against escrow
(define-public (initiate-dispute 
  (escrow-id uint)
  (dispute-reason (string-ascii 300))
)
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR_ESCROW_NOT_FOUND))
  )
    ;; Only donor can initiate disputes
    (asserts! (is-eq tx-sender (get donor escrow)) ERR_UNAUTHORIZED)
    
    ;; Validate escrow status and dispute system
    (asserts! (is-eq (get status escrow) STATUS_VERIFIED) ERR_INVALID_STATUS)
    (asserts! (var-get dispute-resolution-active) ERR_UNAUTHORIZED)
    (asserts! (<= stacks-block-height (+ (get completion-block escrow) DISPUTE_PERIOD)) ERR_DISPUTE_PERIOD_ACTIVE)
    
    ;; Update escrow status
    (map-set escrows escrow-id (merge escrow { status: STATUS_DISPUTED }))
    
    ;; Create dispute record
    (map-set disputes escrow-id {
      escrow-id: escrow-id,
      disputer: tx-sender,
      dispute-reason: dispute-reason,
      dispute-block: stacks-block-height,
      resolution-block: u0,
      resolved: false,
      resolution-in-favor-of-donor: false
    })
    
    (ok true)
  )
)

;; Resolve dispute (admin only)
(define-public (resolve-dispute 
  (escrow-id uint)
  (in-favor-of-donor bool)
)
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR_ESCROW_NOT_FOUND))
    (dispute (unwrap! (map-get? disputes escrow-id) ERR_ESCROW_NOT_FOUND))
  )
    ;; Only contract owner can resolve disputes
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status escrow) STATUS_DISPUTED) ERR_INVALID_STATUS)
    (asserts! (not (get resolved dispute)) ERR_ALREADY_VERIFIED)
    
    ;; Resolve based on decision
    (if in-favor-of-donor
      ;; Refund to donor
      (begin
        (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get donor escrow))))
        (map-set escrows escrow-id (merge escrow { status: STATUS_REFUNDED }))
      )
      ;; Keep funds with shelter (already transferred)
      (map-set escrows escrow-id (merge escrow { status: STATUS_COMPLETED }))
    )
    
    ;; Update dispute record
    (map-set disputes escrow-id (merge dispute {
      resolution-block: stacks-block-height,
      resolved: true,
      resolution-in-favor-of-donor: in-favor-of-donor
    }))
    
    (ok true)
  )
)

;; Handle expired escrows (refund to donor)
(define-public (handle-expired-escrow (escrow-id uint))
  (let (
    (escrow (unwrap! (map-get? escrows escrow-id) ERR_ESCROW_NOT_FOUND))
  )
    ;; Validate escrow is expired and still active
    (asserts! (is-eq (get status escrow) STATUS_ACTIVE) ERR_INVALID_STATUS)
    (asserts! (> stacks-block-height (get expiration-block escrow)) ERR_INVALID_STATUS)
    
    ;; Refund to donor
    (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get donor escrow))))
    
    ;; Update escrow status
    (map-set escrows escrow-id (merge escrow { status: STATUS_EXPIRED }))
    
    (ok true)
  )
)

;; Withdraw platform fees (admin only)
(define-public (withdraw-platform-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (<= amount (var-get platform-fee-collected)) ERR_INSUFFICIENT_BALANCE)
    
    (try! (as-contract (stx-transfer? amount tx-sender (var-get contract-owner))))
    (var-set platform-fee-collected (- (var-get platform-fee-collected) amount))
    
    (ok true)
  )
)

;; Read-only functions

;; Get escrow information
(define-read-only (get-escrow (escrow-id uint))
  (map-get? escrows escrow-id)
)

;; Get service verification
(define-read-only (get-service-verification (escrow-id uint) (verifier principal))
  (map-get? service-verifications { escrow-id: escrow-id, verifier: verifier })
)

;; Get donor history
(define-read-only (get-donor-history (donor principal))
  (map-get? donor-history donor)
)

;; Get dispute information
(define-read-only (get-dispute (escrow-id uint))
  (map-get? disputes escrow-id)
)

;; Get verifier information
(define-read-only (get-verifier (verifier principal))
  (map-get? authorized-verifiers verifier)
)

;; Get platform statistics
(define-read-only (get-platform-stats)
  {
    total-escrows: (var-get total-escrows),
    total-completed-escrows: (var-get total-completed-escrows),
    total-donations: (var-get total-donations),
    platform-fee-collected: (var-get platform-fee-collected),
    dispute-resolution-active: (var-get dispute-resolution-active)
  }
)

;; Check if escrow is active and valid
(define-read-only (is-escrow-active (escrow-id uint))
  (match (map-get? escrows escrow-id)
    escrow (and 
      (is-eq (get status escrow) STATUS_ACTIVE)
      (<= stacks-block-height (get expiration-block escrow))
    )
    false
  )
)

;; Get escrow status summary
(define-read-only (get-escrow-status (escrow-id uint))
  (match (map-get? escrows escrow-id)
    escrow (some {
      status: (get status escrow),
      creation-block: (get creation-block escrow),
      expiration-block: (get expiration-block escrow),
      verified-beneficiaries: (get verified-beneficiaries escrow),
      required-beneficiaries: (get required-beneficiaries escrow)
    })
    none
  )
)

;; Calculate platform fee for amount
(define-read-only (calculate-platform-fee (amount uint))
  (/ (* amount PLATFORM_FEE_BASIS_POINTS) BASIS_POINTS_DIVISOR)
)

;; Get contract owner
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

