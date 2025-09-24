;; title: genetic-acoustics-analyzer
;; version: 1.0.0
;; summary: Processes DNA data for personalized clarinet acoustic optimization
;; description: Smart contract that analyzes genetic markers related to hearing sensitivity,
;;              lung function, and muscle fiber types to determine optimal clarinet specifications

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_GENETIC_DATA (err u101))
(define-constant ERR_PROFILE_NOT_FOUND (err u102))
(define-constant ERR_INVALID_PARAMETERS (err u103))
(define-constant ERR_PROFILE_ALREADY_EXISTS (err u104))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u105))

;; Genetic marker constants for analysis
(define-constant MIN_HEARING_SENSITIVITY u10)
(define-constant MAX_HEARING_SENSITIVITY u100)
(define-constant MIN_LUNG_CAPACITY u2000)
(define-constant MAX_LUNG_CAPACITY u8000)
(define-constant MIN_MUSCLE_FIBER_RATIO u20)
(define-constant MAX_MUSCLE_FIBER_RATIO u80)

;; Clarinet specification constants
(define-constant MIN_BORE_DIAMETER u140) ;; 14.0mm in tenths of mm
(define-constant MAX_BORE_DIAMETER u160) ;; 16.0mm in tenths of mm
(define-constant MIN_KEY_SPACING u180) ;; 18.0mm in tenths of mm
(define-constant MAX_KEY_SPACING u220) ;; 22.0mm in tenths of mm
(define-constant ANALYSIS_FEE u1000000) ;; 1 STX in microSTX

;; data vars
(define-data-var total-profiles uint u0)
(define-data-var contract-enabled bool true)
(define-data-var analysis-fee uint ANALYSIS_FEE)

;; data maps
;; Store genetic profiles with privacy controls
(define-map genetic-profiles
  { user: principal }
  {
    hearing-sensitivity: uint,
    lung-capacity: uint,
    muscle-fiber-ratio: uint,
    profile-hash: (buff 32),
    created-at: uint,
    privacy-level: uint,
    authorized-viewers: (list 10 principal)
  }
)

;; Store acoustic analysis results
(define-map acoustic-analysis
  { user: principal }
  {
    bore-diameter: uint,
    key-spacing: uint,
    tonal-frequency: uint,
    resonance-factor: uint,
    optimal-material: (string-ascii 20),
    confidence-score: uint,
    analysis-date: uint
  }
)

;; Store clarinet specifications
(define-map clarinet-specs
  { user: principal }
  {
    body-length: uint,
    bell-diameter: uint,
    tone-hole-positions: (list 20 uint),
    key-configurations: (list 15 uint),
    reed-hardness: uint,
    mouthpiece-opening: uint,
    manufacturing-tolerance: uint
  }
)

;; Track analysis requests
(define-map analysis-requests
  { request-id: uint }
  {
    user: principal,
    status: (string-ascii 20),
    payment-amount: uint,
    requested-at: uint,
    completed-at: (optional uint)
  }
)

(define-data-var next-request-id uint u1)

;; public functions

;; Submit genetic data for analysis
(define-public (submit-genetic-data 
  (hearing-sensitivity uint)
  (lung-capacity uint) 
  (muscle-fiber-ratio uint)
  (profile-hash (buff 32))
  (privacy-level uint)
  (authorized-viewers (list 10 principal))
)
  (let (
    (caller tx-sender)
    (current-request-id (var-get next-request-id))
  )
    ;; Validate input parameters
    (asserts! (and 
      (>= hearing-sensitivity MIN_HEARING_SENSITIVITY)
      (<= hearing-sensitivity MAX_HEARING_SENSITIVITY)
      (>= lung-capacity MIN_LUNG_CAPACITY)
      (<= lung-capacity MAX_LUNG_CAPACITY)
      (>= muscle-fiber-ratio MIN_MUSCLE_FIBER_RATIO)
      (<= muscle-fiber-ratio MAX_MUSCLE_FIBER_RATIO)
      (<= privacy-level u3)
    ) ERR_INVALID_GENETIC_DATA)
    
    ;; Check if profile already exists
    (asserts! (is-none (map-get? genetic-profiles { user: caller })) ERR_PROFILE_ALREADY_EXISTS)
    
    ;; Validate payment
    (asserts! (>= (stx-get-balance caller) (var-get analysis-fee)) ERR_INSUFFICIENT_PAYMENT)
    
    ;; Transfer analysis fee
    (try! (stx-transfer? (var-get analysis-fee) caller CONTRACT_OWNER))
    
    ;; Store genetic profile
    (map-set genetic-profiles
      { user: caller }
      {
        hearing-sensitivity: hearing-sensitivity,
        lung-capacity: lung-capacity,
        muscle-fiber-ratio: muscle-fiber-ratio,
        profile-hash: profile-hash,
        created-at: stacks-block-height,
        privacy-level: privacy-level,
        authorized-viewers: authorized-viewers
      }
    )
    
    ;; Create analysis request
    (map-set analysis-requests
      { request-id: current-request-id }
      {
        user: caller,
        status: "submitted",
        payment-amount: (var-get analysis-fee),
        requested-at: stacks-block-height,
        completed-at: none
      }
    )
    
    ;; Increment counters
    (var-set total-profiles (+ (var-get total-profiles) u1))
    (var-set next-request-id (+ current-request-id u1))
    
    (ok current-request-id)
  )
)

;; Process genetic analysis and generate acoustic specifications
(define-public (process-acoustic-analysis (user principal))
  (let (
    (profile (unwrap! (map-get? genetic-profiles { user: user }) ERR_PROFILE_NOT_FOUND))
    (hearing (get hearing-sensitivity profile))
    (lung (get lung-capacity profile))
    (muscle (get muscle-fiber-ratio profile))
  )
    ;; Only contract owner can process analysis
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    
    ;; Calculate optimal specifications
    (let (
      (bore-diameter (calculate-bore-diameter hearing lung))
      (key-spacing (calculate-key-spacing muscle hearing))
      (tonal-freq (calculate-tonal-frequency hearing lung))
      (resonance (calculate-resonance-factor lung muscle))
      (material (determine-optimal-material hearing muscle))
      (confidence (calculate-confidence-score hearing lung muscle))
    )
      ;; Store acoustic analysis results
      (map-set acoustic-analysis
        { user: user }
        {
          bore-diameter: bore-diameter,
          key-spacing: key-spacing,
          tonal-frequency: tonal-freq,
          resonance-factor: resonance,
          optimal-material: material,
          confidence-score: confidence,
          analysis-date: stacks-block-height
        }
      )
      
      ;; Generate detailed clarinet specifications
      (let (
        (body-length (calculate-body-length bore-diameter tonal-freq))
        (bell-diameter (calculate-bell-diameter bore-diameter resonance))
        (tone-holes (generate-tone-hole-positions key-spacing bore-diameter))
        (key-configs (generate-key-configurations muscle key-spacing))
        (reed-hardness (determine-reed-hardness lung hearing))
        (mouthpiece-opening (calculate-mouthpiece-opening lung hearing))
        (tolerance (determine-manufacturing-tolerance confidence))
      )
        (map-set clarinet-specs
          { user: user }
          {
            body-length: body-length,
            bell-diameter: bell-diameter,
            tone-hole-positions: tone-holes,
            key-configurations: key-configs,
            reed-hardness: reed-hardness,
            mouthpiece-opening: mouthpiece-opening,
            manufacturing-tolerance: tolerance
          }
        )
      )
      
      (ok true)
    )
  )
)

;; Update privacy settings for genetic profile
(define-public (update-privacy-settings 
  (privacy-level uint)
  (authorized-viewers (list 10 principal))
)
  (let (
    (caller tx-sender)
    (profile (unwrap! (map-get? genetic-profiles { user: caller }) ERR_PROFILE_NOT_FOUND))
  )
    (asserts! (<= privacy-level u3) ERR_INVALID_PARAMETERS)
    
    (map-set genetic-profiles
      { user: caller }
      (merge profile {
        privacy-level: privacy-level,
        authorized-viewers: authorized-viewers
      })
    )
    
    (ok true)
  )
)

;; Admin function to update analysis fee
(define-public (update-analysis-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set analysis-fee new-fee)
    (ok true)
  )
)

;; read only functions

;; Get genetic profile (with privacy controls)
(define-read-only (get-genetic-profile (user principal) (viewer principal))
  (let (
    (profile (map-get? genetic-profiles { user: user }))
  )
    (match profile
      some-profile
        (let (
          (privacy-level (get privacy-level some-profile))
          (authorized-viewers (get authorized-viewers some-profile))
        )
          (if (or 
            (is-eq user viewer)
            (is-eq viewer CONTRACT_OWNER)
            (is-eq privacy-level u0)
            (is-some (index-of authorized-viewers viewer))
          )
            (some some-profile)
            none
          )
        )
      none
    )
  )
)

;; Get acoustic analysis results
(define-read-only (get-acoustic-analysis (user principal))
  (map-get? acoustic-analysis { user: user })
)

;; Get clarinet specifications
(define-read-only (get-clarinet-specs (user principal))
  (map-get? clarinet-specs { user: user })
)

;; Get analysis request status
(define-read-only (get-analysis-request (request-id uint))
  (map-get? analysis-requests { request-id: request-id })
)

;; Get total number of profiles
(define-read-only (get-total-profiles)
  (var-get total-profiles)
)

;; Get current analysis fee
(define-read-only (get-analysis-fee)
  (var-get analysis-fee)
)

;; private functions

;; Calculate optimal bore diameter based on hearing and lung capacity
(define-private (calculate-bore-diameter (hearing uint) (lung uint))
  (let (
    (hearing-factor (/ (* hearing u20) u100))
    (lung-factor (/ (* lung u10) MAX_LUNG_CAPACITY))
    (base-diameter (+ MIN_BORE_DIAMETER (/ (- MAX_BORE_DIAMETER MIN_BORE_DIAMETER) u2)))
  )
    (+ base-diameter (- hearing-factor lung-factor))
  )
)

;; Calculate key spacing based on muscle fiber ratio and hearing
(define-private (calculate-key-spacing (muscle uint) (hearing uint))
  (let (
    (muscle-factor (/ (* muscle u30) u100))
    (hearing-adjustment (/ hearing u10))
    (base-spacing (+ MIN_KEY_SPACING (/ (- MAX_KEY_SPACING MIN_KEY_SPACING) u2)))
  )
    (+ base-spacing muscle-factor (- hearing-adjustment u5))
  )
)

;; Calculate tonal frequency preferences
(define-private (calculate-tonal-frequency (hearing uint) (lung uint))
  (let (
    (hearing-freq (+ u440 (* hearing u2)))
    (lung-adjustment (/ lung u200))
  )
    (+ hearing-freq lung-adjustment)
  )
)

;; Calculate resonance factor
(define-private (calculate-resonance-factor (lung uint) (muscle uint))
  (let (
    (lung-resonance (/ (* lung u50) MAX_LUNG_CAPACITY))
    (muscle-dampening (/ muscle u100))
  )
    (- lung-resonance muscle-dampening)
  )
)

;; Determine optimal material based on genetics
(define-private (determine-optimal-material (hearing uint) (muscle uint))
  (if (> hearing u70)
    (if (> muscle u60)
      "grenadilla-wood"
      "rosewood"
    )
    (if (> muscle u50)
      "ebonite"
      "abs-resin"
    )
  )
)

;; Calculate confidence score for analysis
(define-private (calculate-confidence-score (hearing uint) (lung uint) (muscle uint))
  (let (
    (hearing-validity (if (and (>= hearing u30) (<= hearing u90)) u30 u10))
    (lung-validity (if (and (>= lung u3000) (<= lung u7000)) u35 u15))
    (muscle-validity (if (and (>= muscle u30) (<= muscle u70)) u35 u15))
  )
    (+ hearing-validity lung-validity muscle-validity)
  )
)

;; Additional specification calculations
(define-private (calculate-body-length (bore-diameter uint) (tonal-freq uint))
  (+ u590 (- u600 tonal-freq) (/ bore-diameter u10))
)

(define-private (calculate-bell-diameter (bore-diameter uint) (resonance uint))
  (+ (* bore-diameter u4) resonance)
)

(define-private (generate-tone-hole-positions (key-spacing uint) (bore-diameter uint))
  (list 
    (* key-spacing u1) (* key-spacing u2) (* key-spacing u3) (* key-spacing u4)
    (* key-spacing u5) (* key-spacing u6) (* key-spacing u7) (* key-spacing u8)
    (* key-spacing u9) (* key-spacing u10) (* key-spacing u11) (* key-spacing u12)
    (* key-spacing u13) (* key-spacing u14) (* key-spacing u15) (* key-spacing u16)
    (* key-spacing u17) (* key-spacing u18) (* key-spacing u19) (* key-spacing u20)
  )
)

(define-private (generate-key-configurations (muscle uint) (key-spacing uint))
  (list 
    muscle (+ muscle u5) (+ muscle u10) (+ muscle u15) (+ muscle u20)
    (+ muscle u25) (+ muscle u30) (+ muscle u35) (+ muscle u40) (+ muscle u45)
    (+ muscle u50) (+ muscle u55) (+ muscle u60) (+ muscle u65) (+ muscle u70)
  )
)

(define-private (determine-reed-hardness (lung uint) (hearing uint))
  (+ u20 (/ lung u300) (/ hearing u20))
)

(define-private (calculate-mouthpiece-opening (lung uint) (hearing uint))
  (+ u100 (/ (* lung u30) MAX_LUNG_CAPACITY) (/ hearing u5))
)

(define-private (determine-manufacturing-tolerance (confidence uint))
  (if (> confidence u80)
    u1  ;; 0.1mm tolerance
    (if (> confidence u60)
      u2  ;; 0.2mm tolerance
      u5  ;; 0.5mm tolerance
    )
  )
)
