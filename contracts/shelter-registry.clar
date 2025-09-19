;; Shelter Registry Smart Contract
;; Manages shelter registration, verification, and performance tracking

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_REGISTERED (err u101))
(define-constant ERR_SHELTER_NOT_FOUND (err u102))
(define-constant ERR_INVALID_CAPACITY (err u103))
(define-constant ERR_INVALID_STATUS (err u104))
(define-constant ERR_INSUFFICIENT_BALANCE (err u105))
(define-constant ERR_ALREADY_VERIFIED (err u106))
(define-constant ERR_INVALID_RATING (err u107))

;; Shelter status constants
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)

;; Service type constants
(define-constant SERVICE_MEALS u1)
(define-constant SERVICE_SHELTER u2)
(define-constant SERVICE_MEDICAL u4)
(define-constant SERVICE_SOCIAL u8)

;; Minimum registration fee (in microSTX)
(define-constant MIN_REGISTRATION_FEE u1000000) ;; 1 STX

;; Data Variables
(define-data-var next-shelter-id uint u1)
(define-data-var contract-owner principal tx-sender)
(define-data-var total-shelters uint u0)
(define-data-var total-verified-shelters uint u0)
(define-data-var registration-fee uint MIN_REGISTRATION_FEE)

;; Data Maps

;; Main shelter registry
(define-map shelters principal {
  id: uint,
  name: (string-ascii 100),
  capacity: uint,
  services: uint, ;; Bitfield for service types
  status: uint,
  registration-block: uint,
  verification-block: uint,
  last-activity-block: uint,
  total-donations-received: uint,
  total-people-served: uint,
  performance-rating: uint, ;; Out of 100
  compliance-score: uint, ;; Out of 100
  description: (string-ascii 500)
})

;; Shelter ID to principal mapping
(define-map shelter-ids uint principal)

;; Shelter verifiers (authorized entities that can verify shelters)
(define-map authorized-verifiers principal bool)

;; Shelter performance metrics
(define-map performance-metrics principal {
  total-escrows: uint,
  completed-escrows: uint,
  disputed-escrows: uint,
  average-service-time: uint,
  beneficiary-feedback-score: uint,
  compliance-violations: uint
})

;; Monthly shelter statistics
(define-map monthly-stats { shelter: principal, year: uint, month: uint } {
  people-served: uint,
  meals-provided: uint,
  nights-shelter: uint,
  donations-received: uint,
  services-rendered: uint
})

;; Service offerings per shelter
(define-map service-details principal {
  meal-capacity: uint,
  bed-capacity: uint,
  medical-services: bool,
  social-services: bool,
  emergency-services: bool,
  operating-hours: (string-ascii 100),
  contact-info: (string-ascii 200)
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

;; Update registration fee
(define-public (update-registration-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (>= new-fee MIN_REGISTRATION_FEE) ERR_INSUFFICIENT_BALANCE)
    (var-set registration-fee new-fee)
    (ok true)
  )
)

;; Add authorized verifier
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set authorized-verifiers verifier true)
    (ok true)
  )
)

;; Remove authorized verifier
(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set authorized-verifiers verifier false)
    (ok true)
  )
)

;; Core shelter management functions

;; Register a new shelter
(define-public (register-shelter 
  (name (string-ascii 100))
  (capacity uint)
  (services uint)
  (description (string-ascii 500))
  (contact-info (string-ascii 200))
)
  (let (
    (shelter-id (var-get next-shelter-id))
    (registration-cost (var-get registration-fee))
  )
    ;; Check if shelter is already registered
    (asserts! (is-none (map-get? shelters tx-sender)) ERR_ALREADY_REGISTERED)
    
    ;; Validate inputs
    (asserts! (> capacity u0) ERR_INVALID_CAPACITY)
    (asserts! (> (len name) u0) ERR_INVALID_STATUS)
    
    ;; Transfer registration fee
    (try! (stx-transfer? registration-cost tx-sender (var-get contract-owner)))
    
    ;; Create shelter record
    (map-set shelters tx-sender {
      id: shelter-id,
      name: name,
      capacity: capacity,
      services: services,
      status: STATUS_PENDING,
      registration-block: stacks-block-height,
      verification-block: u0,
      last-activity-block: stacks-block-height,
      total-donations-received: u0,
      total-people-served: u0,
      performance-rating: u50, ;; Start with neutral rating
      compliance-score: u100,
      description: description
    })
    
    ;; Set shelter ID mapping
    (map-set shelter-ids shelter-id tx-sender)
    
    ;; Initialize performance metrics
    (map-set performance-metrics tx-sender {
      total-escrows: u0,
      completed-escrows: u0,
      disputed-escrows: u0,
      average-service-time: u0,
      beneficiary-feedback-score: u50,
      compliance-violations: u0
    })
    
    ;; Set service details
    (map-set service-details tx-sender {
      meal-capacity: (if (> (bit-and services SERVICE_MEALS) u0) capacity u0),
      bed-capacity: (if (> (bit-and services SERVICE_SHELTER) u0) capacity u0),
      medical-services: (> (bit-and services SERVICE_MEDICAL) u0),
      social-services: (> (bit-and services SERVICE_SOCIAL) u0),
      emergency-services: true,
      operating-hours: "24/7",
      contact-info: contact-info
    })
    
    ;; Update counters
    (var-set next-shelter-id (+ shelter-id u1))
    (var-set total-shelters (+ (var-get total-shelters) u1))
    
    (ok shelter-id)
  )
)

;; Verify a shelter (by authorized verifier)
(define-public (verify-shelter (shelter principal))
  (let (
    (shelter-data (unwrap! (map-get? shelters shelter) ERR_SHELTER_NOT_FOUND))
    (is-verifier (default-to false (map-get? authorized-verifiers tx-sender)))
  )
    ;; Check authorization
    (asserts! (or is-verifier (is-eq tx-sender (var-get contract-owner))) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status shelter-data) STATUS_PENDING) ERR_ALREADY_VERIFIED)
    
    ;; Update shelter status
    (map-set shelters shelter (merge shelter-data {
      status: STATUS_VERIFIED,
      verification-block: stacks-block-height
    }))
    
    ;; Update verified shelter count
    (var-set total-verified-shelters (+ (var-get total-verified-shelters) u1))
    
    (ok true)
  )
)

;; Suspend shelter operations
(define-public (suspend-shelter (shelter principal) (reason (string-ascii 200)))
  (let (
    (shelter-data (unwrap! (map-get? shelters shelter) ERR_SHELTER_NOT_FOUND))
    (is-verifier (default-to false (map-get? authorized-verifiers tx-sender)))
  )
    ;; Check authorization
    (asserts! (or is-verifier (is-eq tx-sender (var-get contract-owner))) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status shelter-data) STATUS_VERIFIED) ERR_INVALID_STATUS)
    
    ;; Update shelter status
    (map-set shelters shelter (merge shelter-data {
      status: STATUS_SUSPENDED,
      last-activity-block: stacks-block-height
    }))
    
    (ok true)
  )
)

;; Update shelter information
(define-public (update-shelter-info 
  (new-capacity uint)
  (new-services uint)
  (new-description (string-ascii 500))
)
  (let (
    (shelter-data (unwrap! (map-get? shelters tx-sender) ERR_SHELTER_NOT_FOUND))
  )
    ;; Only allow updates if shelter is verified or pending
    (asserts! (or 
      (is-eq (get status shelter-data) STATUS_VERIFIED)
      (is-eq (get status shelter-data) STATUS_PENDING)
    ) ERR_INVALID_STATUS)
    
    ;; Validate new capacity
    (asserts! (> new-capacity u0) ERR_INVALID_CAPACITY)
    
    ;; Update shelter information
    (map-set shelters tx-sender (merge shelter-data {
      capacity: new-capacity,
      services: new-services,
      description: new-description,
      last-activity-block: stacks-block-height
    }))
    
    ;; Update service details
    (let (
      (current-details (unwrap! (map-get? service-details tx-sender) ERR_SHELTER_NOT_FOUND))
    )
      (map-set service-details tx-sender (merge current-details {
        meal-capacity: (if (> (bit-and new-services SERVICE_MEALS) u0) new-capacity u0),
        bed-capacity: (if (> (bit-and new-services SERVICE_SHELTER) u0) new-capacity u0),
        medical-services: (> (bit-and new-services SERVICE_MEDICAL) u0),
        social-services: (> (bit-and new-services SERVICE_SOCIAL) u0)
      }))
    )
    
    (ok true)
  )
)

;; Update shelter performance metrics (called by escrow contract)
(define-public (update-performance-metrics 
  (shelter principal)
  (people-served uint)
  (donations-received uint)
  (service-completed bool)
)
  (let (
    (shelter-data (unwrap! (map-get? shelters shelter) ERR_SHELTER_NOT_FOUND))
    (metrics (default-to {
      total-escrows: u0,
      completed-escrows: u0,
      disputed-escrows: u0,
      average-service-time: u0,
      beneficiary-feedback-score: u50,
      compliance-violations: u0
    } (map-get? performance-metrics shelter)))
  )
    ;; Update shelter statistics
    (map-set shelters shelter (merge shelter-data {
      total-people-served: (+ (get total-people-served shelter-data) people-served),
      total-donations-received: (+ (get total-donations-received shelter-data) donations-received),
      last-activity-block: stacks-block-height
    }))
    
    ;; Update performance metrics
    (map-set performance-metrics shelter (merge metrics {
      total-escrows: (+ (get total-escrows metrics) u1),
      completed-escrows: (if service-completed 
        (+ (get completed-escrows metrics) u1)
        (get completed-escrows metrics)
      )
    }))
    
    ;; Calculate and update performance rating
    (let (
      (completion-rate (if (> (get total-escrows metrics) u0)
        (/ (* (get completed-escrows metrics) u100) (get total-escrows metrics))
        u50
      ))
      (new-rating (if (> completion-rate u100) u100 (if (< completion-rate u0) u0 completion-rate)))
    )
      (map-set shelters shelter (merge shelter-data {
        performance-rating: new-rating
      }))
    )
    
    (ok true)
  )
)

;; Record monthly statistics
(define-public (record-monthly-stats 
  (people-served uint)
  (meals-provided uint)
  (nights-shelter uint)
  (services-rendered uint)
)
  (let (
    (current-block stacks-block-height)
    (current-month (/ current-block u4320)) ;; Approximate blocks per month
    (current-year (/ current-month u12))
    (month-key { shelter: tx-sender, year: current-year, month: (mod current-month u12) })
  )
    ;; Verify shelter is registered
    (asserts! (is-some (map-get? shelters tx-sender)) ERR_SHELTER_NOT_FOUND)
    
    ;; Get current month stats or create new
    (let (
      (current-stats (default-to {
        people-served: u0,
        meals-provided: u0,
        nights-shelter: u0,
        donations-received: u0,
        services-rendered: u0
      } (map-get? monthly-stats month-key)))
    )
      ;; Update monthly statistics
      (map-set monthly-stats month-key {
        people-served: (+ (get people-served current-stats) people-served),
        meals-provided: (+ (get meals-provided current-stats) meals-provided),
        nights-shelter: (+ (get nights-shelter current-stats) nights-shelter),
        donations-received: (get donations-received current-stats), ;; Updated by escrow
        services-rendered: (+ (get services-rendered current-stats) services-rendered)
      })
    )
    
    (ok true)
  )
)

;; Read-only functions

;; Get shelter information
(define-read-only (get-shelter (shelter principal))
  (map-get? shelters shelter)
)

;; Get shelter by ID
(define-read-only (get-shelter-by-id (id uint))
  (match (map-get? shelter-ids id)
    shelter-principal (map-get? shelters shelter-principal)
    none
  )
)

;; Check if shelter is verified
(define-read-only (is-shelter-verified (shelter principal))
  (match (map-get? shelters shelter)
    shelter-data (is-eq (get status shelter-data) STATUS_VERIFIED)
    false
  )
)

;; Get shelter performance metrics
(define-read-only (get-performance-metrics (shelter principal))
  (map-get? performance-metrics shelter)
)

;; Get shelter service details
(define-read-only (get-service-details (shelter principal))
  (map-get? service-details shelter)
)

;; Get monthly statistics
(define-read-only (get-monthly-stats (shelter principal) (year uint) (month uint))
  (map-get? monthly-stats { shelter: shelter, year: year, month: month })
)

;; Get total statistics
(define-read-only (get-total-stats)
  {
    total-shelters: (var-get total-shelters),
    total-verified-shelters: (var-get total-verified-shelters),
    registration-fee: (var-get registration-fee)
  }
)

;; Check if principal is authorized verifier
(define-read-only (is-authorized-verifier (verifier principal))
  (default-to false (map-get? authorized-verifiers verifier))
)

;; Check shelter capacity and availability
(define-read-only (get-shelter-capacity (shelter principal))
  (match (map-get? shelters shelter)
    shelter-data (some {
      total-capacity: (get capacity shelter-data),
      services: (get services shelter-data),
      status: (get status shelter-data)
    })
    none
  )
)

;; Get contract owner
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

