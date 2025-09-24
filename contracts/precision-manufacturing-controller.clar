;; title: precision-manufacturing-controller
;; version: 1.0.0
;; summary: Controls 3D printing and CNC machining for custom clarinet production
;; description: Smart contract that manages manufacturing orders, quality control,
;;              and precision equipment operation for DNA-personalized clarinets

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_ORDER_NOT_FOUND (err u201))
(define-constant ERR_INVALID_SPECIFICATIONS (err u202))
(define-constant ERR_MANUFACTURING_IN_PROGRESS (err u203))
(define-constant ERR_INSUFFICIENT_MATERIALS (err u204))
(define-constant ERR_QUALITY_CHECK_FAILED (err u205))
(define-constant ERR_EQUIPMENT_UNAVAILABLE (err u206))
(define-constant ERR_INVALID_TOLERANCE (err u207))
(define-constant ERR_ORDER_ALREADY_COMPLETED (err u208))

;; Manufacturing constants
(define-constant MIN_TOLERANCE u1)     ;; 0.1mm in tenths of mm
(define-constant MAX_TOLERANCE u10)    ;; 1.0mm in tenths of mm
(define-constant MIN_MATERIAL_UNITS u100)
(define-constant MAX_MATERIAL_UNITS u10000)
(define-constant MANUFACTURING_FEE u2000000) ;; 2 STX in microSTX
(define-constant QUALITY_CHECK_THRESHOLD u85)

;; Equipment type constants
(define-constant EQUIPMENT_3D_PRINTER u1)
(define-constant EQUIPMENT_CNC_LATHE u2)
(define-constant EQUIPMENT_DRILL_PRESS u3)
(define-constant EQUIPMENT_POLISHING_UNIT u4)
(define-constant EQUIPMENT_ASSEMBLY_STATION u5)

;; Manufacturing stage constants
(define-constant STAGE_BODY_CREATION u1)
(define-constant STAGE_TONE_HOLE_DRILLING u2)
(define-constant STAGE_KEY_MANUFACTURING u3)
(define-constant STAGE_BELL_SHAPING u4)
(define-constant STAGE_ASSEMBLY u5)
(define-constant STAGE_QUALITY_CONTROL u6)
(define-constant STAGE_FINISHING u7)

;; data vars
(define-data-var total-orders uint u0)
(define-data-var active-orders uint u0)
(define-data-var manufacturing-fee uint MANUFACTURING_FEE)
(define-data-var production-capacity uint u10)
(define-data-var next-order-id uint u1)

;; Equipment availability tracking
(define-data-var printer-available bool true)
(define-data-var cnc-available bool true)
(define-data-var drill-available bool true)
(define-data-var polisher-available bool true)
(define-data-var assembly-available bool true)

;; data maps
;; Store manufacturing orders
(define-map manufacturing-orders
  { order-id: uint }
  {
    customer: principal,
    genetic-profile-hash: (buff 32),
    specifications: {
      body-length: uint,
      bore-diameter: uint,
      key-spacing: uint,
      bell-diameter: uint,
      tolerance: uint,
      material: (string-ascii 20)
    },
    order-status: (string-ascii 20),
    current-stage: uint,
    created-at: uint,
    estimated-completion: uint,
    actual-completion: (optional uint),
    total-cost: uint
  }
)

;; Track manufacturing stages for each order
(define-map manufacturing-stages
  { order-id: uint, stage: uint }
  {
    equipment-used: uint,
    operator: principal,
    started-at: uint,
    completed-at: (optional uint),
    quality-score: (optional uint),
    measurements: (list 10 uint),
    stage-status: (string-ascii 15)
  }
)

;; Store component details for each order
(define-map manufactured-components
  { order-id: uint }
  {
    body-dimensions: (list 5 uint),
    tone-hole-positions: (list 20 uint),
    tone-hole-diameters: (list 20 uint),
    key-dimensions: (list 15 uint),
    bell-measurements: (list 3 uint),
    material-composition: (string-ascii 50),
    surface-finish: (string-ascii 20),
    weight: uint
  }
)

;; Quality control records
(define-map quality-records
  { order-id: uint }
  {
    dimensional-accuracy: uint,
    surface-quality: uint,
    acoustic-properties: uint,
    assembly-precision: uint,
    overall-score: uint,
    inspector: principal,
    inspection-date: uint,
    certification-status: (string-ascii 15),
    notes: (string-ascii 200)
  }
)

;; Equipment maintenance and usage tracking
(define-map equipment-status
  { equipment-id: uint }
  {
    equipment-type: (string-ascii 20),
    current-status: (string-ascii 15),
    last-maintenance: uint,
    operating-hours: uint,
    precision-calibration: uint,
    next-maintenance-due: uint
  }
)

;; Material inventory tracking
(define-map material-inventory
  { material-type: (string-ascii 20) }
  {
    current-stock: uint,
    reserved-stock: uint,
    minimum-threshold: uint,
    unit-cost: uint,
    supplier: (string-ascii 30),
    last-restocked: uint
  }
)

;; public functions

;; Submit manufacturing order with genetic specifications
(define-public (submit-manufacturing-order
  (genetic-profile-hash (buff 32))
  (body-length uint)
  (bore-diameter uint)
  (key-spacing uint)
  (bell-diameter uint)
  (tolerance uint)
  (material (string-ascii 20))
)
  (let (
    (caller tx-sender)
    (current-order-id (var-get next-order-id))
    (estimated-completion (+ stacks-block-height u2016)) ;; ~2 weeks
  )
    ;; Validate specifications
    (asserts! (and
      (> body-length u500)
      (< body-length u700)
      (>= bore-diameter u140)
      (<= bore-diameter u160)
      (>= key-spacing u180)
      (<= key-spacing u220)
      (>= tolerance MIN_TOLERANCE)
      (<= tolerance MAX_TOLERANCE)
    ) ERR_INVALID_SPECIFICATIONS)
    
    ;; Check production capacity
    (asserts! (< (var-get active-orders) (var-get production-capacity)) ERR_EQUIPMENT_UNAVAILABLE)
    
    ;; Validate payment
    (asserts! (>= (stx-get-balance caller) (var-get manufacturing-fee)) ERR_INSUFFICIENT_MATERIALS)
    
    ;; Transfer manufacturing fee
    (try! (stx-transfer? (var-get manufacturing-fee) caller CONTRACT_OWNER))
    
    ;; Create manufacturing order
    (map-set manufacturing-orders
      { order-id: current-order-id }
      {
        customer: caller,
        genetic-profile-hash: genetic-profile-hash,
        specifications: {
          body-length: body-length,
          bore-diameter: bore-diameter,
          key-spacing: key-spacing,
          bell-diameter: bell-diameter,
          tolerance: tolerance,
          material: material
        },
        order-status: "submitted",
        current-stage: u0,
        created-at: stacks-block-height,
        estimated-completion: estimated-completion,
        actual-completion: none,
        total-cost: (var-get manufacturing-fee)
      }
    )
    
    ;; Reserve materials
    (try! (reserve-materials material body-length))
    
    ;; Update counters
    (var-set total-orders (+ (var-get total-orders) u1))
    (var-set active-orders (+ (var-get active-orders) u1))
    (var-set next-order-id (+ current-order-id u1))
    
    (ok current-order-id)
  )
)

;; Start manufacturing stage for an order
(define-public (start-manufacturing-stage (order-id uint) (stage uint) (equipment-id uint))
  (let (
    (order (unwrap! (map-get? manufacturing-orders { order-id: order-id }) ERR_ORDER_NOT_FOUND))
  )
    ;; Only authorized operators can start stages
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-operator tx-sender)) ERR_UNAUTHORIZED)
    
    ;; Validate stage progression
    (asserts! (is-eq (+ (get current-stage order) u1) stage) ERR_MANUFACTURING_IN_PROGRESS)
    
    ;; Check equipment availability
    (asserts! (is-equipment-available equipment-id) ERR_EQUIPMENT_UNAVAILABLE)
    
    ;; Create stage record
    (map-set manufacturing-stages
      { order-id: order-id, stage: stage }
      {
        equipment-used: equipment-id,
        operator: tx-sender,
        started-at: stacks-block-height,
        completed-at: none,
        quality-score: none,
        measurements: (list),
        stage-status: "in-progress"
      }
    )
    
    ;; Update order status
    (map-set manufacturing-orders
      { order-id: order-id }
      (merge order {
        current-stage: stage,
        order-status: "manufacturing"
      })
    )
    
    ;; Mark equipment as busy
    (try! (set-equipment-status equipment-id false))
    
    (ok true)
  )
)

;; Complete manufacturing stage with measurements
(define-public (complete-manufacturing-stage
  (order-id uint)
  (stage uint)
  (measurements (list 10 uint))
  (quality-score uint)
)
  (let (
    (stage-record (unwrap! (map-get? manufacturing-stages { order-id: order-id, stage: stage }) ERR_ORDER_NOT_FOUND))
    (equipment-id (get equipment-used stage-record))
  )
    ;; Only the operator who started the stage can complete it
    (asserts! (is-eq tx-sender (get operator stage-record)) ERR_UNAUTHORIZED)
    
    ;; Validate quality score
    (asserts! (and (>= quality-score u0) (<= quality-score u100)) ERR_QUALITY_CHECK_FAILED)
    
    ;; Update stage record
    (map-set manufacturing-stages
      { order-id: order-id, stage: stage }
      (merge stage-record {
        completed-at: (some stacks-block-height),
        quality-score: (some quality-score),
        measurements: measurements,
        stage-status: "completed"
      })
    )
    
    ;; Release equipment
    (try! (set-equipment-status equipment-id true))
    
    ;; Check if all stages are complete
    (if (is-eq stage STAGE_FINISHING)
      (complete-manufacturing-order order-id)
      (ok true)
    )
  )
)

;; Perform quality control inspection
(define-public (perform-quality-inspection
  (order-id uint)
  (dimensional-accuracy uint)
  (surface-quality uint)
  (acoustic-properties uint)
  (assembly-precision uint)
  (notes (string-ascii 200))
)
  (let (
    (order (unwrap! (map-get? manufacturing-orders { order-id: order-id }) ERR_ORDER_NOT_FOUND))
    (overall-score (/ (+ dimensional-accuracy surface-quality acoustic-properties assembly-precision) u4))
  )
    ;; Only authorized inspectors can perform quality control
    (asserts! (or (is-eq tx-sender CONTRACT_OWNER) (is-authorized-inspector tx-sender)) ERR_UNAUTHORIZED)
    
    ;; Ensure order is in quality control stage
    (asserts! (is-eq (get current-stage order) STAGE_QUALITY_CONTROL) ERR_MANUFACTURING_IN_PROGRESS)
    
    ;; Store quality record
    (map-set quality-records
      { order-id: order-id }
      {
        dimensional-accuracy: dimensional-accuracy,
        surface-quality: surface-quality,
        acoustic-properties: acoustic-properties,
        assembly-precision: assembly-precision,
        overall-score: overall-score,
        inspector: tx-sender,
        inspection-date: stacks-block-height,
        certification-status: (if (>= overall-score QUALITY_CHECK_THRESHOLD) "certified" "rejected"),
        notes: notes
      }
    )
    
    ;; Update order based on quality results
    (if (>= overall-score QUALITY_CHECK_THRESHOLD)
      (map-set manufacturing-orders
        { order-id: order-id }
        (merge order { order-status: "quality-approved" })
      )
      (map-set manufacturing-orders
        { order-id: order-id }
        (merge order { order-status: "quality-rejected" })
      )
    )
    
    (ok overall-score)
  )
)

;; Update manufacturing fee (admin only)
(define-public (update-manufacturing-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set manufacturing-fee new-fee)
    (ok true)
  )
)

;; read only functions

;; Get manufacturing order details
(define-read-only (get-manufacturing-order (order-id uint))
  (map-get? manufacturing-orders { order-id: order-id })
)

;; Get manufacturing stage details
(define-read-only (get-manufacturing-stage (order-id uint) (stage uint))
  (map-get? manufacturing-stages { order-id: order-id, stage: stage })
)

;; Get manufactured components
(define-read-only (get-manufactured-components (order-id uint))
  (map-get? manufactured-components { order-id: order-id })
)

;; Get quality record
(define-read-only (get-quality-record (order-id uint))
  (map-get? quality-records { order-id: order-id })
)

;; Get equipment status
(define-read-only (get-equipment-status (equipment-id uint))
  (map-get? equipment-status { equipment-id: equipment-id })
)

;; Get material inventory
(define-read-only (get-material-inventory (material-type (string-ascii 20)))
  (map-get? material-inventory { material-type: material-type })
)

;; Get production statistics
(define-read-only (get-production-stats)
  {
    total-orders: (var-get total-orders),
    active-orders: (var-get active-orders),
    production-capacity: (var-get production-capacity),
    manufacturing-fee: (var-get manufacturing-fee)
  }
)

;; private functions

;; Reserve materials for manufacturing order
(define-private (reserve-materials (material (string-ascii 20)) (quantity uint))
  (let (
    (inventory (default-to 
      { current-stock: u0, reserved-stock: u0, minimum-threshold: u10, unit-cost: u100, supplier: "default", last-restocked: u0 }
      (map-get? material-inventory { material-type: material })
    ))
    (available-stock (- (get current-stock inventory) (get reserved-stock inventory)))
  )
    (if (>= available-stock quantity)
      (begin
        (map-set material-inventory
          { material-type: material }
          (merge inventory { reserved-stock: (+ (get reserved-stock inventory) quantity) })
        )
        (ok true)
      )
      ERR_INSUFFICIENT_MATERIALS
    )
  )
)

;; Check if equipment is available
(define-private (is-equipment-available (equipment-id uint))
  (if (is-eq equipment-id u1)
    (var-get printer-available)
    (if (is-eq equipment-id u2)
      (var-get cnc-available)
      (if (is-eq equipment-id u3)
        (var-get drill-available)
        (if (is-eq equipment-id u4)
          (var-get polisher-available)
          (if (is-eq equipment-id u5)
            (var-get assembly-available)
            false
          )
        )
      )
    )
  )
)

;; Set equipment availability status
(define-private (set-equipment-status (equipment-id uint) (available bool))
  (if (is-eq equipment-id u1)
    (begin (var-set printer-available available) (ok true))
    (if (is-eq equipment-id u2)
      (begin (var-set cnc-available available) (ok true))
      (if (is-eq equipment-id u3)
        (begin (var-set drill-available available) (ok true))
        (if (is-eq equipment-id u4)
          (begin (var-set polisher-available available) (ok true))
          (if (is-eq equipment-id u5)
            (begin (var-set assembly-available available) (ok true))
            ERR_EQUIPMENT_UNAVAILABLE
          )
        )
      )
    )
  )
)

;; Complete manufacturing order
(define-private (complete-manufacturing-order (order-id uint))
  (let (
    (order (unwrap! (map-get? manufacturing-orders { order-id: order-id }) ERR_ORDER_NOT_FOUND))
  )
    ;; Update order status
    (map-set manufacturing-orders
      { order-id: order-id }
      (merge order {
        order-status: "completed",
        actual-completion: (some stacks-block-height)
      })
    )
    
    ;; Decrease active orders count
    (var-set active-orders (- (var-get active-orders) u1))
    
    (ok true)
  )
)

;; Authorization helpers
(define-private (is-authorized-operator (operator principal))
  ;; In a real implementation, this would check against an authorized operators list
  (is-eq operator CONTRACT_OWNER)
)

(define-private (is-authorized-inspector (inspector principal))
  ;; In a real implementation, this would check against an authorized inspectors list
  (is-eq inspector CONTRACT_OWNER)
)

;; Calculate manufacturing time estimate
(define-private (estimate-manufacturing-time (tolerance uint) (material (string-ascii 20)))
  (let (
    (base-time u1008) ;; ~1 week in blocks
    (tolerance-factor (if (<= tolerance u2) u504 u0)) ;; Extra time for high precision
    (material-factor (if (is-eq material "grenadilla-wood") u504 u0)) ;; Extra time for hardwood
  )
    (+ base-time tolerance-factor material-factor)
  )
)

;; Generate component specifications based on genetic analysis
(define-private (generate-component-specs (order-id uint))
  (let (
    (order (unwrap-panic (map-get? manufacturing-orders { order-id: order-id })))
    (specs (get specifications order))
  )
    (map-set manufactured-components
      { order-id: order-id }
      {
        body-dimensions: (list (get body-length specs) (get bore-diameter specs) u45 u32 u28),
        tone-hole-positions: (calculate-tone-hole-positions (get key-spacing specs)),
        tone-hole-diameters: (generate-tone-hole-diameters (get bore-diameter specs)),
        key-dimensions: (calculate-key-dimensions (get key-spacing specs)),
        bell-measurements: (list (get bell-diameter specs) u85 u120),
        material-composition: (get material specs),
        surface-finish: "polished",
        weight: (calculate-component-weight (get body-length specs) (get material specs))
      }
    )
  )
)

;; Helper functions for component calculations
(define-private (calculate-tone-hole-positions (key-spacing uint))
  (list 
    (* key-spacing u1) (* key-spacing u2) (* key-spacing u3) (* key-spacing u4)
    (* key-spacing u5) (* key-spacing u6) (* key-spacing u7) (* key-spacing u8)
    (* key-spacing u9) (* key-spacing u10) (* key-spacing u11) (* key-spacing u12)
    (* key-spacing u13) (* key-spacing u14) (* key-spacing u15) (* key-spacing u16)
    (* key-spacing u17) (* key-spacing u18) (* key-spacing u19) (* key-spacing u20)
  )
)

(define-private (generate-tone-hole-diameters (bore-diameter uint))
  (let ((base-diameter (/ bore-diameter u10)))
    (list 
      base-diameter (+ base-diameter u1) (+ base-diameter u2) (+ base-diameter u1)
      base-diameter (+ base-diameter u3) base-diameter (+ base-diameter u2)
      (+ base-diameter u1) base-diameter (+ base-diameter u2) (+ base-diameter u1)
      base-diameter (+ base-diameter u3) (+ base-diameter u1) base-diameter
      (+ base-diameter u2) base-diameter (+ base-diameter u1) (+ base-diameter u3)
    )
  )
)

(define-private (calculate-key-dimensions (key-spacing uint))
  (list 
    key-spacing (+ key-spacing u5) (+ key-spacing u3) (+ key-spacing u7)
    (+ key-spacing u2) (+ key-spacing u8) (+ key-spacing u4) (+ key-spacing u6)
    (+ key-spacing u1) (+ key-spacing u9) (+ key-spacing u3) (+ key-spacing u5)
    (+ key-spacing u7) (+ key-spacing u2) (+ key-spacing u4)
  )
)

(define-private (calculate-component-weight (body-length uint) (material (string-ascii 20)))
  (let (
    (base-weight (* body-length u2)) ;; Base weight calculation
    (material-density (if (is-eq material "grenadilla-wood") u130
                        (if (is-eq material "rosewood") u110
                          (if (is-eq material "ebonite") u95 u85))))
  )
    (/ (* base-weight material-density) u100)
  )
)
