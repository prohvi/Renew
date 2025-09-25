;; Green Energy Farm Contract
;; Invest in renewable energy and earn carbon credits
(define-fungible-token carbon-credit)
(define-constant ENERGY-ADMIN tx-sender)

;; Error Codes
(define-constant ERR-UNAUTHORIZED-USER (err u101))
(define-constant ERR-INSUFFICIENT-INVESTMENT (err u102))
(define-constant ERR-NO-INVESTMENT-FOUND (err u103))
(define-constant ERR-GENERATOR-OFFLINE (err u104))
(define-constant ERR-INVALID-GENERATOR (err u105))
(define-constant ERR-INVALID-EFFICIENCY (err u106))
(define-constant ERR-INVALID-CREDIT-RATE (err u107))
(define-constant ERR-EMPTY-TYPE-NAME (err u108))

;; Energy System Variables
(define-data-var maintenance-mode bool false)
(define-data-var shutdown-loss uint u12) ;; 12% loss during emergency shutdown
(define-data-var credits-per-kwh uint u5)
(define-data-var total-capacity uint u0)
(define-data-var generator-types uint u0)

;; Constants for validation
(define-constant MAX-EFFICIENCY u100)
(define-constant MAX-CREDIT-RATE u1000)
(define-constant MIN-TYPE-NAME-LENGTH u1)

;; Data Maps
(define-map energy-generators
  { gen-id: uint }
  { type-name: (string-ascii 25), efficiency: uint, credit-rate: uint, capacity: uint, online: bool }
)

(define-map investor-holdings
  { investor: principal, gen-id: uint }
  { invested-amount: uint, last-harvest-block: uint }
)

;; Validation functions
(define-private (validate-type-name (type-name (string-ascii 25)))
  (> (len type-name) u0)
)

(define-private (validate-efficiency (efficiency uint))
  (and (> efficiency u0) (<= efficiency MAX-EFFICIENCY))
)

(define-private (validate-credit-rate (credit-rate uint))
  (and (> credit-rate u0) (<= credit-rate MAX-CREDIT-RATE))
)

(define-private (validate-gen-id (gen-id uint))
  (< gen-id (var-get generator-types))
)

;; Initialize energy farm
(define-public (setup-energy-farm)
  (begin
    (try! (ft-mint? carbon-credit u750000 ENERGY-ADMIN))
    (try! (install-generator "Solar Panel" u3 u85))
    (try! (install-generator "Wind Turbine" u6 u125))
    (try! (install-generator "Hydroelectric" u9 u170))
    (ok true)
  )
)

;; Install new energy generator with input validation
(define-public (install-generator (type-name (string-ascii 25)) (efficiency uint) (credit-rate uint))
  (begin
    (asserts! (is-eq tx-sender ENERGY-ADMIN) ERR-UNAUTHORIZED-USER)
    (asserts! (validate-type-name type-name) ERR-EMPTY-TYPE-NAME)
    (asserts! (validate-efficiency efficiency) ERR-INVALID-EFFICIENCY)
    (asserts! (validate-credit-rate credit-rate) ERR-INVALID-CREDIT-RATE)
    (let ((new-gen-id (var-get generator-types)))
      (map-set energy-generators { gen-id: new-gen-id }
        { type-name: type-name, efficiency: efficiency, credit-rate: credit-rate, capacity: u0, online: true })
      (var-set generator-types (+ new-gen-id u1))
      (ok new-gen-id)
    )
  )
)

;; Invest in energy generator with input validation
(define-public (invest-in-energy (gen-id uint) (investment uint))
  (begin
    (asserts! (> investment u0) ERR-INSUFFICIENT-INVESTMENT)
    (asserts! (validate-gen-id gen-id) ERR-INVALID-GENERATOR)
    (let ((generator (unwrap! (map-get? energy-generators { gen-id: gen-id }) ERR-INVALID-GENERATOR)))
      (asserts! (get online generator) ERR-GENERATOR-OFFLINE)
      (try! (ft-transfer? carbon-credit investment tx-sender (as-contract tx-sender)))
      (let ((current-holding (default-to { invested-amount: u0, last-harvest-block: stacks-block-height }
              (map-get? investor-holdings { investor: tx-sender, gen-id: gen-id }))))
        (if (> (get invested-amount current-holding) u0)
          (try! (distribute-credits tx-sender (calculate-energy-credits tx-sender gen-id)))
          true)
        (map-set investor-holdings { investor: tx-sender, gen-id: gen-id }
          { invested-amount: (+ (get invested-amount current-holding) investment),
            last-harvest-block: stacks-block-height })
        (map-set energy-generators { gen-id: gen-id }
          (merge generator { capacity: (+ (get capacity generator) investment) }))
        (var-set total-capacity (+ (var-get total-capacity) investment))
        (ok true)
      )
    )
  )
)

;; Divest from energy generator with input validation
(define-public (divest-from-energy (gen-id uint) (amount uint))
  (begin
    (asserts! (validate-gen-id gen-id) ERR-INVALID-GENERATOR)
    (let ((holding (unwrap! (map-get? investor-holdings { investor: tx-sender, gen-id: gen-id }) ERR-NO-INVESTMENT-FOUND))
          (generator (unwrap! (map-get? energy-generators { gen-id: gen-id }) ERR-INVALID-GENERATOR)))
      (asserts! (<= amount (get invested-amount holding)) ERR-INSUFFICIENT-INVESTMENT)
      (try! (distribute-credits tx-sender (calculate-energy-credits tx-sender gen-id)))
      (try! (as-contract (ft-transfer? carbon-credit amount tx-sender tx-sender)))
      (map-set investor-holdings { investor: tx-sender, gen-id: gen-id }
        { invested-amount: (- (get invested-amount holding) amount),
          last-harvest-block: stacks-block-height })
      (ok true)
    )
  )
)

;; Emergency shutdown withdrawal with input validation
(define-public (emergency-shutdown-exit (gen-id uint))
  (begin
    (asserts! (var-get maintenance-mode) ERR-UNAUTHORIZED-USER)
    (asserts! (validate-gen-id gen-id) ERR-INVALID-GENERATOR)
    (let ((holding (unwrap! (map-get? investor-holdings { investor: tx-sender, gen-id: gen-id }) ERR-NO-INVESTMENT-FOUND))
          (invested (get invested-amount holding))
          (loss-amount (/ (* invested (var-get shutdown-loss)) u100)))
      (try! (as-contract (ft-transfer? carbon-credit (- invested loss-amount) tx-sender tx-sender)))
      (map-delete investor-holdings { investor: tx-sender, gen-id: gen-id })
      (ok (- invested loss-amount))
    )
  )
)

;; Calculate energy credits earned with input validation
(define-private (calculate-energy-credits (investor principal) (gen-id uint))
  (let ((holding (unwrap! (map-get? investor-holdings { investor: investor, gen-id: gen-id }) u0))
        (generator (unwrap! (map-get? energy-generators { gen-id: gen-id }) u0))
        (blocks-producing (- stacks-block-height (get last-harvest-block holding))))
    (if (and (> (get capacity generator) u0) (validate-gen-id gen-id))
      (/ (* (get invested-amount holding) blocks-producing (var-get credits-per-kwh) (get credit-rate generator))
         (* (get capacity generator) u100))
      u0)
  )
)

(define-private (distribute-credits (investor principal) (credit-amount uint))
  (ft-mint? carbon-credit credit-amount investor)
)

;; Admin functions
(define-public (toggle-maintenance (active bool))
  (begin
    (asserts! (is-eq tx-sender ENERGY-ADMIN) ERR-UNAUTHORIZED-USER)
    (var-set maintenance-mode active)
    (ok active)
  )
)

;; Read-only functions with input validation
(define-read-only (get-investment-status (investor principal) (gen-id uint))
  (if (validate-gen-id gen-id)
    (default-to { invested-amount: u0, last-harvest-block: u0 }
      (map-get? investor-holdings { investor: investor, gen-id: gen-id }))
    { invested-amount: u0, last-harvest-block: u0 }
  )
)

(define-read-only (get-generator-details (gen-id uint))
  (if (validate-gen-id gen-id)
    (map-get? energy-generators { gen-id: gen-id })
    none
  )
)

(define-read-only (get-farm-overview)
  { total-capacity: (var-get total-capacity),
    maintenance-mode: (var-get maintenance-mode),
    generator-types: (var-get generator-types) }
)