;; title: Labordao

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u1001))
(define-constant ERR_MEMBER_NOT_FOUND (err u1002))
(define-constant ERR_ALREADY_VOTED (err u1003))
(define-constant ERR_PROPOSAL_ENDED (err u1004))
(define-constant ERR_PROPOSAL_NOT_ENDED (err u1005))
(define-constant ERR_INSUFFICIENT_VOTES (err u1006))
(define-constant ERR_ALREADY_MEMBER (err u1007))
(define-constant ERR_INVALID_PROPOSAL_TYPE (err u1008))
(define-constant ERR_INVALID_VOTING_PERIOD (err u1009))

(define-data-var proposal-counter uint u0)
(define-data-var member-counter uint u0)
(define-data-var min-quorum uint u10)
(define-data-var voting-period-blocks uint u144)

(define-map members 
    { member-id: uint }
    { 
        address: principal,
        union-position: (string-ascii 50),
        voting-power: uint,
        joined-at: uint,
        active: bool
    })

(define-map member-lookup 
    { address: principal }
    { member-id: uint })

(define-map proposals 
    { proposal-id: uint }
    {
        title: (string-ascii 100),
        description: (string-ascii 500),
        proposal-type: (string-ascii 30),
        proposer: principal,
        created-at: uint,
        voting-ends-at: uint,
        for-votes: uint,
        against-votes: uint,
        executed: bool,
        minimum-quorum: uint
    })

(define-map votes 
    { proposal-id: uint, member-id: uint }
    { 
        vote: bool,
        voting-power: uint,
        voted-at: uint
    })

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals { proposal-id: proposal-id }))

(define-read-only (get-member (member-id uint))
    (map-get? members { member-id: member-id }))

(define-read-only (get-member-by-address (address principal))
    (match (map-get? member-lookup { address: address })
        lookup-result (map-get? members { member-id: (get member-id lookup-result) })
        none))

(define-read-only (get-vote (proposal-id uint) (member-id uint))
    (map-get? votes { proposal-id: proposal-id, member-id: member-id }))

(define-read-only (get-proposal-counter)
    (var-get proposal-counter))

(define-read-only (get-member-counter)
    (var-get member-counter))

(define-read-only (get-min-quorum)
    (var-get min-quorum))

(define-read-only (get-voting-period)
    (var-get voting-period-blocks))

(define-read-only (is-proposal-active (proposal-id uint))
    (match (get-proposal proposal-id)
        proposal-data 
        (let ((ends-at (get voting-ends-at proposal-data)))
            (< stacks-block-height ends-at))
        false))

(define-read-only (get-proposal-results (proposal-id uint))
    (match (get-proposal proposal-id)
        proposal-data 
        (let 
            (
                (for-votes (get for-votes proposal-data))
                (against-votes (get against-votes proposal-data))
                (total-votes (+ for-votes against-votes))
                (quorum-met (>= total-votes (get minimum-quorum proposal-data)))
                (proposal-passed (and quorum-met (> for-votes against-votes)))
            )
            (ok {
                for-votes: for-votes,
                against-votes: against-votes,
                total-votes: total-votes,
                quorum-met: quorum-met,
                passed: proposal-passed
            }))
        ERR_PROPOSAL_NOT_FOUND))

(define-public (join-union (union-position (string-ascii 50)) (voting-power uint))
    (let 
        (
            (caller tx-sender)
            (new-member-id (+ (var-get member-counter) u1))
        )
        (asserts! (is-none (map-get? member-lookup { address: caller })) ERR_ALREADY_MEMBER)
        (map-set members 
            { member-id: new-member-id }
            {
                address: caller,
                union-position: union-position,
                voting-power: voting-power,
                joined-at: stacks-block-height,
                active: true
            })
        (map-set member-lookup 
            { address: caller }
            { member-id: new-member-id })
        (var-set member-counter new-member-id)
        (ok new-member-id)))

(define-public (create-proposal 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (proposal-type (string-ascii 30)))
    (let 
        (
            (caller tx-sender)
            (new-proposal-id (+ (var-get proposal-counter) u1))
            (current-block stacks-block-height)
            (voting-ends (+ current-block (var-get voting-period-blocks)))
        )
        (asserts! (is-some (get-member-by-address caller)) ERR_MEMBER_NOT_FOUND)
        (map-set proposals 
            { proposal-id: new-proposal-id }
            {
                title: title,
                description: description,
                proposal-type: proposal-type,
                proposer: caller,
                created-at: current-block,
                voting-ends-at: voting-ends,
                for-votes: u0,
                against-votes: u0,
                executed: false,
                minimum-quorum: (var-get min-quorum)
            })
        (var-set proposal-counter new-proposal-id)
        (ok new-proposal-id)))

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
    (let 
        (
            (caller tx-sender)
            (member-data (unwrap! (get-member-by-address caller) ERR_MEMBER_NOT_FOUND))
            (member-lookup-data (unwrap! (map-get? member-lookup { address: caller }) ERR_MEMBER_NOT_FOUND))
            (member-id (get member-id member-lookup-data))
            (voting-power (get voting-power member-data))
            (proposal-data (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
        )
        (asserts! (get active member-data) ERR_UNAUTHORIZED)
        (asserts! (is-none (get-vote proposal-id member-id)) ERR_ALREADY_VOTED)
        (asserts! (is-proposal-active proposal-id) ERR_PROPOSAL_ENDED)
        
        (map-set votes 
            { proposal-id: proposal-id, member-id: member-id }
            {
                vote: vote-for,
                voting-power: voting-power,
                voted-at: stacks-block-height
            })
        
        (if vote-for
            (map-set proposals 
                { proposal-id: proposal-id }
                (merge proposal-data { for-votes: (+ (get for-votes proposal-data) voting-power) }))
            (map-set proposals 
                { proposal-id: proposal-id }
                (merge proposal-data { against-votes: (+ (get against-votes proposal-data) voting-power) })))
        (ok true)))

(define-public (execute-proposal (proposal-id uint))
    (let 
        (
            (proposal-data (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
            (results (unwrap! (get-proposal-results proposal-id) ERR_PROPOSAL_NOT_FOUND))
        )
        (asserts! (not (is-proposal-active proposal-id)) ERR_PROPOSAL_NOT_ENDED)
        (asserts! (not (get executed proposal-data)) ERR_PROPOSAL_NOT_FOUND)
        (asserts! (get passed results) ERR_INSUFFICIENT_VOTES)
        
        (map-set proposals 
            { proposal-id: proposal-id }
            (merge proposal-data { executed: true }))
        (ok true)))

(define-public (update-member-status (member-id uint) (active bool))
    (let ((member-data (unwrap! (get-member member-id) ERR_MEMBER_NOT_FOUND)))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (map-set members 
            { member-id: member-id }
            (merge member-data { active: active }))
        (ok true)))

(define-public (set-min-quorum (new-quorum uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set min-quorum new-quorum)
        (ok true)))

(define-public (set-voting-period (new-period uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (asserts! (> new-period u0) ERR_INVALID_VOTING_PERIOD)
        (var-set voting-period-blocks new-period)
        (ok true)))

(define-public (emergency-pause-member (member-address principal))
    (let ((member-lookup-data (unwrap! (map-get? member-lookup { address: member-address }) ERR_MEMBER_NOT_FOUND)))
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (update-member-status (get member-id member-lookup-data) false)))
