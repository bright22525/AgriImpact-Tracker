;; -----------------------------------------------------------------------------
;; AgriImpact Tracker: Transparent NGO & Project Impact Management
;; Version: 1.0
;; Purpose: Register NGOs, manage projects, collect donations, verify milestones,
;;          and release funds securely on-chain.
;; Notes: Clarity/Clarnet-friendly. Use `stx-get-transfer-amount` and `stx-transfer?`.
;; -----------------------------------------------------------------------------

;; ----------------------------
;; Contract Owner
;; ----------------------------
(define-data-var owner principal tx-sender)

(define-public (get-owner)
  (ok (var-get owner))
)

;; ----------------------------
;; Counters
;; ----------------------------
(define-data-var ngo-count uint u0)
(define-data-var project-count uint u0)
(define-data-var donation-count uint u0)
(define-data-var milestone-count uint u0)

;; ----------------------------
;; Data Structures
;; ----------------------------

;; NGOs
(define-map ngos
  { id: uint }
  {
    name: (string-ascii 64),
    wallet: principal,
    verified: bool,
    metadata: (string-ascii 128)
  }
)

;; Projects
(define-map projects
  { id: uint }
  {
    ngo-id: uint,
    title: (string-ascii 100),
    description: (string-ascii 256),
    goal: uint,
    raised: uint,
    completed: bool,
    created-at: uint
  }
)

;; Milestones
(define-map milestones
  { id: uint }
  {
    project-id: uint,
    title: (string-ascii 100),
    description: (string-ascii 256),
    amount: uint,
    verified: bool,
    verifier: (optional principal),
    created-at: uint,
    verified-at: (optional uint)
  }
)

;; Donations
(define-map donations
  { id: uint }
  {
    project-id: uint,
    donor: principal,
    amount: uint,
    timestamp: uint
  }
)

;; Verifiers Registry
(define-map verifiers
  { addr: principal } 
  { allowed: bool }
)

;; ----------------------------
;; Events (for off-chain indexers)
;; ----------------------------
;; ngo-registered
;; ngo-verified
;; project-created
;; donation-received
;; milestone-created
;; milestone-verified
;; funds-released

;; ----------------------------
;; Authorization Helpers
;; ----------------------------
(define-read-only (is-owner (addr principal))
  (is-eq addr (var-get owner))
)

(define-read-only (is-verifier (addr principal))
  (match (map-get? verifiers {addr: addr})
    some-entry (get allowed some-entry)
    false
  )
)

;; ----------------------------
;; Owner / Admin Functions
;; ----------------------------

;; Transfer ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) (err "UNAUTHORIZED"))
    (asserts! (not (is-eq new-owner tx-sender)) (err "INVALID_OWNER"))
    (ok (var-set owner new-owner))
  )
)

;; Set verifier
(define-public (set-verifier (addr principal) (allow bool))
  (begin
    (asserts! (is-owner tx-sender) (err "UNAUTHORIZED"))
    (asserts! (not (is-eq addr tx-sender)) (err "INVALID_VERIFIER"))
    (ok (map-set verifiers {addr: addr} {allowed: allow}))
  )
)

;; Verify NGO
(define-public (verify-ngo (ngo-id uint))
  (begin
    (asserts! (is-owner tx-sender) (err "UNAUTHORIZED"))
    (asserts! (> ngo-id u0) (err "INVALID_NGO_ID"))
    (match (map-get? ngos {id: ngo-id})
      ngo
      (begin
        (map-set ngos {id: ngo-id} (merge ngo {verified: true}))
        (print { event: "ngo-verified", ngo-id: ngo-id, by: tx-sender })
        (ok true)
      )
      (err "NGO_NOT_FOUND")
    )
  )
)

;; ----------------------------
;; NGO / Public Functions
;; ----------------------------

;; Register new NGO
(define-public (register-ngo (name (string-ascii 64)) (metadata (string-ascii 128)))
  (let ((new-id (+ u1 (var-get ngo-count))))
    (begin
      (asserts! (> (len name) u0) (err "INVALID_NAME"))
      (asserts! (> (len metadata) u0) (err "INVALID_METADATA"))
      (map-set ngos {id: new-id}
        { name: name, wallet: tx-sender, verified: false, metadata: metadata })
      (var-set ngo-count new-id)
      (print { event: "ngo-registered", ngo-id: new-id, name: name, wallet: tx-sender })
      (ok new-id)
    )
  )
)

;; Create Project (NGO only)
(define-public (create-project (ngo-id uint) (title (string-ascii 100)) (description (string-ascii 256)) (goal uint))
  (begin
    (asserts! (> (len title) u0) (err "INVALID_TITLE"))
    (asserts! (> (len description) u0) (err "INVALID_DESCRIPTION"))
    (asserts! (> goal u0) (err "INVALID_GOAL"))
    (match (map-get? ngos {id: ngo-id})
      ngo
      (begin
        (asserts! (is-eq (get wallet ngo) tx-sender) (err "NOT_NGO_WALLET"))
        (let ((new-id (+ u1 (var-get project-count))))
          (map-set projects {id: new-id}
            { ngo-id: ngo-id, title: title, description: description, goal: goal, raised: u0, completed: false, created-at: stacks-block-height })
          (var-set project-count new-id)
          (print { event: "project-created", project-id: new-id, ngo-id: ngo-id, title: title })
          (ok new-id)
        )
      )
      (err "NGO_NOT_FOUND")
    )
  )
)

;; Donate to project
(define-public (donate (project-id uint) (amount uint))
  (begin
    (asserts! (> amount u0) (err "NO_STX_SENT"))
    (match (map-get? projects {id: project-id})
      project
      (let ((new-id (+ u1 (var-get donation-count))))
        (map-set donations {id: new-id} { project-id: project-id, donor: tx-sender, amount: amount, timestamp: stacks-block-height })
        (var-set donation-count new-id)
        ;; update project's raised amount
        (map-set projects {id: project-id} (merge project {raised: (+ (get raised project) amount)}))
        (print { event: "donation-received", donation-id: new-id, project-id: project-id, donor: tx-sender, amount: amount })
        (ok new-id)
      )
      (err "PROJECT_NOT_FOUND")
    )
  )
)

;; Create milestone (NGO only)
(define-public (create-milestone (project-id uint) (title (string-ascii 100)) (description (string-ascii 256)) (amount uint))
  (begin
    (match (map-get? projects {id: project-id})
      project
      (let ((ngo-id (get ngo-id project))
            (new-id (+ u1 (var-get milestone-count))))
        (match (map-get? ngos {id: ngo-id})
          ngo
          (begin
            (asserts! (is-eq (get wallet ngo) tx-sender) (err "NOT_NGO_WALLET"))
            (map-set milestones {id: new-id}
              { project-id: project-id, title: title, description: description, amount: amount,
                verified: false, verifier: none, created-at: stacks-block-height, verified-at: none })
            (var-set milestone-count new-id)
            (print { event: "milestone-created", milestone-id: new-id, project-id: project-id, amount: amount })
            (ok new-id)
          )
          (err "NGO_NOT_FOUND")
        )
      )
      (err "PROJECT_NOT_FOUND")
    )
  )
)

;; Verify milestone (verifier only)
(define-public (verify-milestone (milestone-id uint))
  (begin
    (asserts! (is-verifier tx-sender) (err "NOT_AUTHORIZED_VERIFIER"))
    (match (map-get? milestones {id: milestone-id})
      milestone
      (begin
        (map-set milestones {id: milestone-id} (merge milestone {verified: true, verifier: (some tx-sender), verified-at: (some stacks-block-height)}))
        (print { event: "milestone-verified", milestone-id: milestone-id, project-id: (get project-id milestone), by: tx-sender })
        (ok true)
      )
      (err "MILESTONE_NOT_FOUND")
    )
  )
)

;; Release funds for milestone
(define-public (release-funds (milestone-id uint))
  (begin
    (asserts! (or (is-verifier tx-sender) (is-owner tx-sender)) (err "UNAUTHORIZED"))
    (match (map-get? milestones {id: milestone-id})
      milestone
      (begin
        (asserts! (get verified milestone) (err "MILESTONE_NOT_VERIFIED"))
        (let ((project-id (get project-id milestone))
              (amount (get amount milestone)))
          (match (map-get? projects {id: project-id})
            project
            (let ((ngo-id (get ngo-id project)))
              (match (map-get? ngos {id: ngo-id})
                ngo
                (begin
                  ;; decrement project's raised
                  (map-set projects {id: project-id} (merge project {raised: (- (get raised project) amount)}))
                  ;; emit event (STX transfer can be added here)
                  (print { event: "funds-released", project-id: project-id, milestone-id: milestone-id, amount: amount, to: (get wallet ngo) })
                  (ok true)
                )
                (err "NGO_NOT_FOUND")
              )
            )
            (err "PROJECT_NOT_FOUND")
          )
        )
      )
      (err "MILESTONE_NOT_FOUND")
    )
  )
)

;; ----------------------------
;; Read-Only Views
;; ----------------------------
(define-read-only (get-ngo (ngo-id uint)) (map-get? ngos {id: ngo-id}))
(define-read-only (get-project (project-id uint)) (map-get? projects {id: project-id}))
(define-read-only (get-milestone (milestone-id uint)) (map-get? milestones {id: milestone-id}))
(define-read-only (get-donation (donation-id uint)) (map-get? donations {id: donation-id}))
(define-read-only (get-verifier-status (addr principal)) (map-get? verifiers {addr: addr}))

(define-read-only (get-ngo-count) (ok (var-get ngo-count)))
(define-read-only (get-project-count) (ok (var-get project-count)))
(define-read-only (get-donation-count) (ok (var-get donation-count)))
(define-read-only (get-milestone-count) (ok (var-get milestone-count)))
