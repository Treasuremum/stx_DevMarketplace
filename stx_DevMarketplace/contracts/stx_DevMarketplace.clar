;; STX Development Marketplace - Decentralized Stacks Development Platform
;; Smart contract for connecting STX/Bitcoin developers with development projects
;; Specialized for Clarity smart contracts, Bitcoin integration, and STX ecosystem development

(define-constant contract-admin tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-PROJECT (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-ALREADY-FINALIZED (err u103))
(define-constant ERR-INVALID-RATING (err u104))
(define-constant ERR-NO-MEDIATOR (err u105))
(define-constant ERR-INVALID-INPUT (err u106))
(define-constant ERR-SELF-PROJECT (err u107))
(define-constant ERR-INVALID-MILESTONE (err u108))
(define-constant ERR-INVALID-STAKE (err u109))
(define-constant ERR-PROJECT-NOT-ACTIVE (err u110))
(define-constant ERR-INVALID-SKILL (err u111))

;; Project categories specific to STX/Bitcoin ecosystem
(define-constant SKILL-CLARITY-DEV "clarity-dev")
(define-constant SKILL-BITCOIN-INTEGRATION "btc-integration")
(define-constant SKILL-DEFI-PROTOCOL "defi-protocol")
(define-constant SKILL-NFT-MARKETPLACE "nft-marketplace")
(define-constant SKILL-WEB3-FRONTEND "web3-frontend")
(define-constant SKILL-STACKS-API "stacks-api")
(define-constant SKILL-ORDINALS-DEV "ordinals-dev")
(define-constant SKILL-LIGHTNING-INTEGRATION "lightning-integration")

;; Core data structures
(define-map Projects
    { project-id: uint }
    {
        client: principal,
        developer: (optional principal),
        payment-amount: uint,
        staked-amount: uint,
        project-title: (string-ascii 128),
        project-description: (string-ascii 1024),
        required-skills: (list 5 (string-ascii 32)),
        project-status: (string-ascii 32),
        difficulty-level: uint, ;; 1-5 scale
        estimated-duration: uint, ;; in blocks
        created-block: uint,
        started-block: uint,
        deadline-block: uint,
        finalized-block: uint,
        mediator: (optional principal),
        milestones-completed: uint,
        total-milestones: uint
    }
)

(define-map DeveloperProfiles
    { user-address: principal }
    {
        total-reviews: uint,
        review-score-sum: uint,
        projects-completed: uint,
        reputation-score: uint,
        skills: (list 8 (string-ascii 32)),
        stx-earned: uint,
        specialization: (string-ascii 64),
        github-verified: bool,
        clarity-contracts-deployed: uint
    }
)

(define-map ProjectMilestones
    { project-id: uint, milestone-id: uint }
    {
        description: (string-ascii 256),
        payment-percentage: uint,
        completed: bool,
        completion-block: uint,
        code-repository: (optional (string-ascii 256))
    }
)

(define-map DeveloperApplications
    { project-id: uint, developer: principal }
    {
        proposal: (string-ascii 512),
        proposed-timeline: uint,
        application-block: uint,
        status: (string-ascii 32) ;; pending, accepted, rejected
    }
)

(define-map ProjectDisputes
    { project-id: uint }
    {
        dispute-reason: (string-ascii 512),
        raised-by: principal,
        raised-block: uint,
        resolved: bool,
        resolution: (optional (string-ascii 512))
    }
)

;; Data variables
(define-data-var project-counter uint u0)
(define-data-var platform-fee-rate uint u300) ;; 3% = 300 basis points
(define-data-var min-developer-stake uint u1000000) ;; 1 STX in microSTX
(define-data-var reputation-threshold uint u50) ;; Minimum reputation for premium features

;; Input validation helpers
(define-private (is-valid-principal (addr principal))
    (not (is-eq addr tx-sender)))

(define-private (is-valid-project-id (project-id uint))
    (and (> project-id u0) (<= project-id (var-get project-counter))))

(define-private (is-valid-description (desc (string-ascii 1024)))
    (and (> (len desc) u0) (<= (len desc) u1024)))

(define-private (is-valid-amount (amount uint))
    (> amount u0))

(define-private (is-valid-skill (skill (string-ascii 32)))
    (or (is-eq skill SKILL-CLARITY-DEV)
        (is-eq skill SKILL-BITCOIN-INTEGRATION)
        (is-eq skill SKILL-DEFI-PROTOCOL)
        (is-eq skill SKILL-NFT-MARKETPLACE)
        (is-eq skill SKILL-WEB3-FRONTEND)
        (is-eq skill SKILL-STACKS-API)
        (is-eq skill SKILL-ORDINALS-DEV)
        (is-eq skill SKILL-LIGHTNING-INTEGRATION)))

(define-private (validate-skills-list (skills (list 5 (string-ascii 32))))
    (fold check-skill-validity skills true))

(define-private (check-skill-validity (skill (string-ascii 32)) (valid-so-far bool))
    (and valid-so-far (is-valid-skill skill)))

;; Create new development project
(define-public (create-project 
    (payment-amount uint) 
    (project-title (string-ascii 128))
    (project-description (string-ascii 1024))
    (required-skills (list 5 (string-ascii 32)))
    (difficulty-level uint)
    (estimated-duration uint)
    (total-milestones uint))
    (let
        ((new-project-id (+ (var-get project-counter) u1))
         (platform-fee (/ (* payment-amount (var-get platform-fee-rate)) u10000))
         (deadline-block (+ stacks-block-height estimated-duration)))
        
        ;; Input validation
        (asserts! (is-valid-amount payment-amount) ERR-INVALID-INPUT)
        (asserts! (> (len project-title) u0) ERR-INVALID-INPUT)
        (asserts! (is-valid-description project-description) ERR-INVALID-INPUT)
        (asserts! (validate-skills-list required-skills) ERR-INVALID-SKILL)
        (asserts! (and (>= difficulty-level u1) (<= difficulty-level u5)) ERR-INVALID-INPUT)
        (asserts! (> estimated-duration u0) ERR-INVALID-INPUT)
        (asserts! (and (> total-milestones u0) (<= total-milestones u10)) ERR-INVALID-MILESTONE)
        (asserts! (>= (stx-get-balance tx-sender) (+ payment-amount platform-fee)) ERR-INSUFFICIENT-BALANCE)
        
        ;; Transfer payment to escrow
        (try! (stx-transfer? (+ payment-amount platform-fee) tx-sender (as-contract tx-sender)))
        
        ;; Create project
        (map-set Projects
            { project-id: new-project-id }
            {
                client: tx-sender,
                developer: none,
                payment-amount: payment-amount,
                staked-amount: u0,
                project-title: project-title,
                project-description: project-description,
                required-skills: required-skills,
                project-status: "open",
                difficulty-level: difficulty-level,
                estimated-duration: estimated-duration,
                created-block: stacks-block-height,
                started-block: u0,
                deadline-block: deadline-block,
                finalized-block: u0,
                mediator: none,
                milestones-completed: u0,
                total-milestones: total-milestones
            }
        )
        (var-set project-counter new-project-id)
        (ok new-project-id)))

;; Developer applies for project
(define-public (apply-for-project 
    (project-id uint) 
    (proposal (string-ascii 512))
    (proposed-timeline uint)
    (stake-amount uint))
    (let ((project (unwrap! (map-get? Projects { project-id: project-id }) ERR-INVALID-PROJECT)))
        
        ;; Input validation
        (asserts! (is-valid-project-id project-id) ERR-INVALID-INPUT)
        (asserts! (> (len proposal) u0) ERR-INVALID-INPUT)
        (asserts! (> proposed-timeline u0) ERR-INVALID-INPUT)
        (asserts! (>= stake-amount (var-get min-developer-stake)) ERR-INVALID-STAKE)
        (asserts! (is-eq (get project-status project) "open") ERR-PROJECT-NOT-ACTIVE)
        (asserts! (not (is-eq tx-sender (get client project))) ERR-SELF-PROJECT)
        (asserts! (>= (stx-get-balance tx-sender) stake-amount) ERR-INSUFFICIENT-BALANCE)
        
        ;; Transfer stake to contract
        (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
        
        ;; Record application
        (map-set DeveloperApplications
            { project-id: project-id, developer: tx-sender }
            {
                proposal: proposal,
                proposed-timeline: proposed-timeline,
                application-block: stacks-block-height,
                status: "pending"
            }
        )
        (ok true)))

;; Client accepts developer application
(define-public (accept-developer (project-id uint) (developer-address principal))
    (let ((project (unwrap! (map-get? Projects { project-id: project-id }) ERR-INVALID-PROJECT))
          (application (unwrap! (map-get? DeveloperApplications { project-id: project-id, developer: developer-address }) ERR-INVALID-INPUT)))
        
        ;; Input validation
        (asserts! (is-valid-project-id project-id) ERR-INVALID-INPUT)
        (asserts! (is-eq tx-sender (get client project)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get project-status project) "open") ERR-PROJECT-NOT-ACTIVE)
        (asserts! (is-eq (get status application) "pending") ERR-INVALID-INPUT)
        
        ;; Update project status
        (map-set Projects
            { project-id: project-id }
            (merge project { 
                developer: (some developer-address),
                project-status: "in-progress",
                started-block: stacks-block-height,
                staked-amount: (var-get min-developer-stake)
            })
        )
        
        ;; Update application status
        (map-set DeveloperApplications
            { project-id: project-id, developer: developer-address }
            (merge application { status: "accepted" })
        )
        (ok true)))

;; Complete milestone
(define-public (complete-milestone 
    (project-id uint) 
    (milestone-id uint)
    (code-repository (optional (string-ascii 256))))
    (let ((project (unwrap! (map-get? Projects { project-id: project-id }) ERR-INVALID-PROJECT))
          (milestone (unwrap! (map-get? ProjectMilestones { project-id: project-id, milestone-id: milestone-id }) ERR-INVALID-MILESTONE)))
        
        ;; Input validation
        (asserts! (is-valid-project-id project-id) ERR-INVALID-INPUT)
        (asserts! (is-eq tx-sender (unwrap! (get developer project) ERR-UNAUTHORIZED)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get project-status project) "in-progress") ERR-PROJECT-NOT-ACTIVE)
        (asserts! (not (get completed milestone)) ERR-INVALID-MILESTONE)
        
        ;; Calculate milestone payment
        (let ((milestone-payment (/ (* (get payment-amount project) (get payment-percentage milestone)) u100))
              (new-milestones-completed (+ (get milestones-completed project) u1)))
            
            ;; Transfer milestone payment
            (try! (as-contract (stx-transfer? milestone-payment tx-sender (unwrap! (get developer project) ERR-UNAUTHORIZED))))
            
            ;; Update milestone
            (map-set ProjectMilestones
                { project-id: project-id, milestone-id: milestone-id }
                (merge milestone { 
                    completed: true,
                    completion-block: stacks-block-height,
                    code-repository: code-repository
                })
            )
            
            ;; Update project
            (map-set Projects
                { project-id: project-id }
                (merge project { 
                    milestones-completed: new-milestones-completed,
                    project-status: (if (is-eq new-milestones-completed (get total-milestones project))
                                      "completed" 
                                      "in-progress")
                })
            )
            
            ;; If project completed, update developer stats and return stake
            (if (is-eq new-milestones-completed (get total-milestones project))
                (begin
                    (try! (as-contract (stx-transfer? (get staked-amount project) tx-sender (unwrap! (get developer project) ERR-UNAUTHORIZED))))
                    (update-developer-stats (unwrap! (get developer project) ERR-UNAUTHORIZED) project)
                    (ok true))
                (ok true)))))

;; Submit review for developer
(define-public (submit-review (project-id uint) (review-score uint) (review-comment (string-ascii 256)))
    (let ((project (unwrap! (map-get? Projects { project-id: project-id }) ERR-INVALID-PROJECT))
          (developer-addr (unwrap! (get developer project) ERR-INVALID-INPUT))
          (current-profile (default-to 
            { total-reviews: u0, review-score-sum: u0, projects-completed: u0, reputation-score: u0, 
              skills: (list), stx-earned: u0, specialization: "", github-verified: false, clarity-contracts-deployed: u0 }
            (map-get? DeveloperProfiles { user-address: developer-addr }))))
        
        ;; Input validation
        (asserts! (is-valid-project-id project-id) ERR-INVALID-INPUT)
        (asserts! (is-eq tx-sender (get client project)) ERR-UNAUTHORIZED)
        (asserts! (is-eq (get project-status project) "completed") ERR-INVALID-PROJECT)
        (asserts! (and (>= review-score u1) (<= review-score u5)) ERR-INVALID-RATING)
        
        (let ((new-total-reviews (+ (get total-reviews current-profile) u1))
              (new-score-sum (+ (get review-score-sum current-profile) review-score)))
            (map-set DeveloperProfiles
                { user-address: developer-addr }
                (merge current-profile {
                    total-reviews: new-total-reviews,
                    review-score-sum: new-score-sum,
                    reputation-score: (calculate-reputation new-total-reviews new-score-sum (get projects-completed current-profile))
                })
            ))
        (ok true)))

;; Raise dispute
(define-public (raise-dispute (project-id uint) (dispute-reason (string-ascii 512)))
    (let ((project (unwrap! (map-get? Projects { project-id: project-id }) ERR-INVALID-PROJECT)))
        
        ;; Input validation
        (asserts! (is-valid-project-id project-id) ERR-INVALID-INPUT)
        (asserts! (> (len dispute-reason) u0) ERR-INVALID-INPUT)
        (asserts! (is-eq (get project-status project) "in-progress") ERR-PROJECT-NOT-ACTIVE)
        (asserts! (or (is-eq tx-sender (get client project)) 
                     (is-eq tx-sender (unwrap! (get developer project) ERR-UNAUTHORIZED)))
                 ERR-UNAUTHORIZED)
        
        ;; Create dispute
        (map-set ProjectDisputes
            { project-id: project-id }
            {
                dispute-reason: dispute-reason,
                raised-by: tx-sender,
                raised-block: stacks-block-height,
                resolved: false,
                resolution: none
            }
        )
        
        ;; Update project status
        (map-set Projects
            { project-id: project-id }
            (merge project { project-status: "disputed" })
        )
        (ok true)))

;; Admin functions
(define-public (update-platform-fee (new-fee-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-admin) ERR-UNAUTHORIZED)
        (asserts! (<= new-fee-rate u1000) ERR-INVALID-INPUT) ;; Max 10%
        (var-set platform-fee-rate new-fee-rate)
        (ok true)))

(define-public (update-min-stake (new-min-stake uint))
    (begin
        (asserts! (is-eq tx-sender contract-admin) ERR-UNAUTHORIZED)
        (asserts! (> new-min-stake u0) ERR-INVALID-INPUT)
        (var-set min-developer-stake new-min-stake)
        (ok true)))

;; Internal helper functions
(define-private (update-developer-stats (developer-address principal) (project { client: principal, developer: (optional principal), payment-amount: uint, staked-amount: uint, project-title: (string-ascii 128), project-description: (string-ascii 1024), required-skills: (list 5 (string-ascii 32)), project-status: (string-ascii 32), difficulty-level: uint, estimated-duration: uint, created-block: uint, started-block: uint, deadline-block: uint, finalized-block: uint, mediator: (optional principal), milestones-completed: uint, total-milestones: uint }))
    (let ((current-profile (default-to 
            { total-reviews: u0, review-score-sum: u0, projects-completed: u0, reputation-score: u0, 
              skills: (list), stx-earned: u0, specialization: "", github-verified: false, clarity-contracts-deployed: u0 }
            (map-get? DeveloperProfiles { user-address: developer-address }))))
        (map-set DeveloperProfiles
            { user-address: developer-address }
            (merge current-profile { 
                projects-completed: (+ (get projects-completed current-profile) u1),
                stx-earned: (+ (get stx-earned current-profile) (get payment-amount project))
            })
        )))

(define-private (calculate-reputation (total-reviews uint) (score-sum uint) (projects-completed uint))
    (if (> total-reviews u0)
        (+ (/ (* score-sum u20) total-reviews) (* projects-completed u5))
        (* projects-completed u5)))

;; Read-only functions
(define-read-only (get-project (project-id uint))
    (if (is-valid-project-id project-id)
        (map-get? Projects { project-id: project-id })
        none))

(define-read-only (get-developer-profile (developer-address principal))
    (let ((profile (map-get? DeveloperProfiles { user-address: developer-address })))
        (match profile
            some-profile (ok {
                average-rating: (if (> (get total-reviews some-profile) u0)
                                  (/ (get review-score-sum some-profile) (get total-reviews some-profile))
                                  u0),
                total-reviews: (get total-reviews some-profile),
                projects-completed: (get projects-completed some-profile),
                reputation-score: (get reputation-score some-profile),
                skills: (get skills some-profile),
                stx-earned: (get stx-earned some-profile),
                specialization: (get specialization some-profile),
                github-verified: (get github-verified some-profile),
                clarity-contracts-deployed: (get clarity-contracts-deployed some-profile)
            })
            (err ERR-INVALID-INPUT))))

(define-read-only (get-developer-application (project-id uint) (developer-address principal))
    (map-get? DeveloperApplications { project-id: project-id, developer: developer-address }))

(define-read-only (get-project-dispute (project-id uint))
    (map-get? ProjectDisputes { project-id: project-id }))

(define-read-only (get-milestone (project-id uint) (milestone-id uint))
    (map-get? ProjectMilestones { project-id: project-id, milestone-id: milestone-id }))

(define-read-only (get-platform-stats)
    (ok {
        total-projects: (var-get project-counter),
        platform-fee-rate: (var-get platform-fee-rate),
        min-developer-stake: (var-get min-developer-stake),
        reputation-threshold: (var-get reputation-threshold)
    }))

(define-read-only (is-project-active (project-id uint))
    (match (get-project project-id)
        some-project (or (is-eq (get project-status some-project) "open")
                        (is-eq (get project-status some-project) "in-progress"))
        false))

(define-read-only (get-required-skills)
    (ok (list SKILL-CLARITY-DEV SKILL-BITCOIN-INTEGRATION SKILL-DEFI-PROTOCOL 
              SKILL-NFT-MARKETPLACE SKILL-WEB3-FRONTEND SKILL-STACKS-API 
              SKILL-ORDINALS-DEV SKILL-LIGHTNING-INTEGRATION)))

;; Project search and filtering
(define-read-only (filter-projects-by-skill (skill (string-ascii 32)))
    (if (is-valid-skill skill)
        (ok true) ;; In a real implementation, you'd iterate through projects
        (err ERR-INVALID-SKILL)))

(define-read-only (get-developer-reputation-tier (developer-address principal))
    (match (get-developer-profile developer-address)
        ok-profile (let ((rep-score (get reputation-score ok-profile)))
            (ok (if (>= rep-score u200) "expert"
                   (if (>= rep-score u100) "advanced"
                      (if (>= rep-score u50) "intermediate"
                         "beginner")))))
        err-msg (err err-msg)))