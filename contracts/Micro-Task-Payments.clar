(define-constant CONTRACT_OWNER tx-sender)

(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_TASK_NOT_FOUND (err u101))
(define-constant ERR_TASK_ALREADY_ASSIGNED (err u102))
(define-constant ERR_TASK_NOT_ASSIGNED (err u103))
(define-constant ERR_TASK_ALREADY_COMPLETED (err u104))
(define-constant ERR_TASK_NOT_COMPLETED (err u105))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u106))
(define-constant ERR_INVALID_STATUS (err u107))
(define-constant ERR_DEADLINE_PASSED (err u108))
(define-constant ERR_DEADLINE_NOT_PASSED (err u109))
(define-constant ERR_ALREADY_RATED (err u110))
(define-constant ERR_INVALID_RATING (err u111))

(define-data-var task-counter uint u0)
(define-data-var platform-fee-percentage uint u250)

(define-map tasks
    uint
    {
        creator: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        payment: uint,
        deadline: uint,
        assignee: (optional principal),
        status: (string-ascii 20),
        created-at: uint,
        completed-at: (optional uint),
        rating: (optional uint),
    }
)

(define-map user-profiles
    principal
    {
        total-tasks-created: uint,
        total-tasks-completed: uint,
        total-earnings: uint,
        average-rating: uint,
        rating-count: uint,
    }
)

(define-map task-applications
    {
        task-id: uint,
        applicant: principal,
    }
    {
        message: (string-ascii 200),
        applied-at: uint,
    }
)

(define-map disputes
    uint
    {
        task-id: uint,
        disputed-by: principal,
        reason: (string-ascii 300),
        status: (string-ascii 20),
        created-at: uint,
        resolved-at: (optional uint),
    }
)

(define-data-var dispute-counter uint u0)

(define-public (create-task
        (title (string-ascii 100))
        (description (string-ascii 500))
        (deadline uint)
        (payment uint)
    )
    (let (
            (task-id (+ (var-get task-counter) u1))
            (current-block stacks-block-height)
        )
        (asserts! (> payment u0) ERR_INSUFFICIENT_PAYMENT)
        (asserts! (> deadline current-block) ERR_DEADLINE_PASSED)
        (try! (stx-transfer? payment tx-sender (as-contract tx-sender)))
        (map-set tasks task-id {
            creator: tx-sender,
            title: title,
            description: description,
            payment: payment,
            deadline: deadline,
            assignee: none,
            status: "open",
            created-at: stacks-block-height,
            completed-at: none,
            rating: none,
        })
        (update-user-profile tx-sender u1 u0 u0)
        (var-set task-counter task-id)
        (ok task-id)
    )
)

(define-public (apply-for-task
        (task-id uint)
        (message (string-ascii 200))
    )
    (let ((task (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND)))
        (asserts! (is-eq (get status task) "open") ERR_INVALID_STATUS)
        (asserts! (> (get deadline task) stacks-block-height) ERR_DEADLINE_PASSED)
        (asserts! (not (is-eq tx-sender (get creator task))) ERR_NOT_AUTHORIZED)
        (map-set task-applications {
            task-id: task-id,
            applicant: tx-sender,
        } {
            message: message,
            applied-at: stacks-block-height,
        })
        (ok true)
    )
)

(define-public (assign-task
        (task-id uint)
        (assignee principal)
    )
    (let ((task (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get creator task)) ERR_NOT_AUTHORIZED)
        (asserts! (is-eq (get status task) "open") ERR_INVALID_STATUS)
        (asserts! (> (get deadline task) stacks-block-height) ERR_DEADLINE_PASSED)
        (map-set tasks task-id
            (merge task {
                assignee: (some assignee),
                status: "assigned",
            })
        )
        (ok true)
    )
)

(define-public (complete-task (task-id uint))
    (let ((task (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND)))
        (asserts!
            (is-eq tx-sender (unwrap! (get assignee task) ERR_TASK_NOT_ASSIGNED))
            ERR_NOT_AUTHORIZED
        )
        (asserts! (is-eq (get status task) "assigned") ERR_INVALID_STATUS)
        (map-set tasks task-id
            (merge task {
                status: "completed",
                completed-at: (some stacks-block-height),
            })
        )
        (ok true)
    )
)

(define-public (approve-completion
        (task-id uint)
        (rating uint)
    )
    (let (
            (task (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND))
            (assignee (unwrap! (get assignee task) ERR_TASK_NOT_ASSIGNED))
            (payment (get payment task))
            (platform-fee (/ (* payment (var-get platform-fee-percentage)) u10000))
            (worker-payment (- payment platform-fee))
        )
        (asserts! (is-eq tx-sender (get creator task)) ERR_NOT_AUTHORIZED)
        (asserts! (is-eq (get status task) "completed") ERR_TASK_NOT_COMPLETED)
        (asserts! (<= rating u5) ERR_INVALID_RATING)
        (asserts! (>= rating u1) ERR_INVALID_RATING)
        (try! (as-contract (stx-transfer? worker-payment tx-sender assignee)))
        (try! (as-contract (stx-transfer? platform-fee tx-sender CONTRACT_OWNER)))
        (map-set tasks task-id
            (merge task {
                status: "paid",
                rating: (some rating),
            })
        )
        (update-user-profile assignee u0 u1 worker-payment)
        (update-assignee-rating assignee rating)
        (ok true)
    )
)

(define-public (dispute-task
        (task-id uint)
        (reason (string-ascii 300))
    )
    (let (
            (task (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND))
            (dispute-id (+ (var-get dispute-counter) u1))
        )
        (asserts!
            (or (is-eq tx-sender (get creator task)) (is-eq tx-sender (unwrap! (get assignee task) ERR_TASK_NOT_ASSIGNED)))
            ERR_NOT_AUTHORIZED
        )
        (asserts!
            (or (is-eq (get status task) "assigned") (is-eq (get status task) "completed"))
            ERR_INVALID_STATUS
        )
        (map-set disputes dispute-id {
            task-id: task-id,
            disputed-by: tx-sender,
            reason: reason,
            status: "open",
            created-at: stacks-block-height,
            resolved-at: none,
        })
        (map-set tasks task-id (merge task { status: "disputed" }))
        (var-set dispute-counter dispute-id)
        (ok dispute-id)
    )
)

(define-public (resolve-dispute-creator (dispute-id uint))
    (let (
            (dispute (unwrap! (map-get? disputes dispute-id) ERR_TASK_NOT_FOUND))
            (task-id (get task-id dispute))
            (task (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND))
            (payment (get payment task))
            (platform-fee (/ (* payment (var-get platform-fee-percentage)) u10000))
            (refund-amount (- payment platform-fee))
        )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (is-eq (get status dispute) "open") ERR_INVALID_STATUS)
        (try! (as-contract (stx-transfer? refund-amount tx-sender (get creator task))))
        (try! (as-contract (stx-transfer? platform-fee tx-sender CONTRACT_OWNER)))
        (map-set tasks task-id (merge task { status: "cancelled" }))
        (map-set disputes dispute-id
            (merge dispute {
                status: "resolved",
                resolved-at: (some stacks-block-height),
            })
        )
        (ok true)
    )
)

(define-public (resolve-dispute-assignee (dispute-id uint))
    (let (
            (dispute (unwrap! (map-get? disputes dispute-id) ERR_TASK_NOT_FOUND))
            (task-id (get task-id dispute))
            (task (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND))
            (assignee (unwrap! (get assignee task) ERR_TASK_NOT_ASSIGNED))
            (payment (get payment task))
            (platform-fee (/ (* payment (var-get platform-fee-percentage)) u10000))
            (worker-payment (- payment platform-fee))
        )
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (is-eq (get status dispute) "open") ERR_INVALID_STATUS)
        (try! (as-contract (stx-transfer? worker-payment tx-sender assignee)))
        (try! (as-contract (stx-transfer? platform-fee tx-sender CONTRACT_OWNER)))
        (map-set tasks task-id (merge task { status: "paid" }))
        (update-user-profile assignee u0 u1 worker-payment)
        (update-assignee-rating assignee u3)
        (map-set disputes dispute-id
            (merge dispute {
                status: "resolved",
                resolved-at: (some stacks-block-height),
            })
        )
        (ok true)
    )
)

(define-public (cancel-task (task-id uint))
    (let (
            (task (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND))
            (payment (get payment task))
            (platform-fee (/ (* payment (var-get platform-fee-percentage)) u10000))
            (refund-amount (- payment platform-fee))
        )
        (asserts! (is-eq tx-sender (get creator task)) ERR_NOT_AUTHORIZED)
        (asserts! (is-eq (get status task) "open") ERR_INVALID_STATUS)
        (try! (as-contract (stx-transfer? refund-amount tx-sender (get creator task))))
        (try! (as-contract (stx-transfer? platform-fee tx-sender CONTRACT_OWNER)))
        (map-set tasks task-id (merge task { status: "cancelled" }))
        (ok true)
    )
)

(define-public (set-platform-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (<= new-fee u1000) ERR_INVALID_STATUS)
        (var-set platform-fee-percentage new-fee)
        (ok true)
    )
)

(define-private (update-user-profile
        (user principal)
        (tasks-created uint)
        (tasks-completed uint)
        (earnings uint)
    )
    (let ((current-profile (default-to {
            total-tasks-created: u0,
            total-tasks-completed: u0,
            total-earnings: u0,
            average-rating: u0,
            rating-count: u0,
        }
            (map-get? user-profiles user)
        )))
        (map-set user-profiles user {
            total-tasks-created: (+ (get total-tasks-created current-profile) tasks-created),
            total-tasks-completed: (+ (get total-tasks-completed current-profile) tasks-completed),
            total-earnings: (+ (get total-earnings current-profile) earnings),
            average-rating: (get average-rating current-profile),
            rating-count: (get rating-count current-profile),
        })
    )
)

(define-private (update-assignee-rating
        (assignee principal)
        (new-rating uint)
    )
    (let (
            (current-profile (default-to {
                total-tasks-created: u0,
                total-tasks-completed: u0,
                total-earnings: u0,
                average-rating: u0,
                rating-count: u0,
            }
                (map-get? user-profiles assignee)
            ))
            (current-rating (get average-rating current-profile))
            (rating-count (get rating-count current-profile))
            (new-rating-count (+ rating-count u1))
            (new-average (if (is-eq rating-count u0)
                new-rating
                (/ (+ (* current-rating rating-count) new-rating)
                    new-rating-count
                )
            ))
        )
        (map-set user-profiles assignee
            (merge current-profile {
                average-rating: new-average,
                rating-count: new-rating-count,
            })
        )
    )
)

(define-read-only (get-task (task-id uint))
    (map-get? tasks task-id)
)

(define-read-only (get-user-profile (user principal))
    (map-get? user-profiles user)
)

(define-read-only (get-task-application
        (task-id uint)
        (applicant principal)
    )
    (map-get? task-applications {
        task-id: task-id,
        applicant: applicant,
    })
)

(define-read-only (get-dispute (dispute-id uint))
    (map-get? disputes dispute-id)
)

(define-read-only (get-platform-fee)
    (var-get platform-fee-percentage)
)

(define-read-only (get-task-counter)
    (var-get task-counter)
)

(define-read-only (get-dispute-counter)
    (var-get dispute-counter)
)

(define-read-only (get-tasks-by-status (status (string-ascii 20)))
    (ok status)
)

(define-read-only (get-tasks-by-creator (creator principal))
    (ok creator)
)

(define-read-only (get-tasks-by-assignee (assignee principal))
    (ok assignee)
)

(define-public (extend-deadline
        (task-id uint)
        (new-deadline uint)
    )
    (let ((task (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND)))
        (asserts! (is-eq tx-sender (get creator task)) ERR_NOT_AUTHORIZED)
        (asserts! (is-eq (get status task) "assigned") ERR_INVALID_STATUS)
        (asserts! (> new-deadline stacks-block-height) ERR_DEADLINE_PASSED)
        (asserts! (> new-deadline (get deadline task)) ERR_DEADLINE_PASSED)
        (map-set tasks task-id (merge task { deadline: new-deadline }))
        (ok true)
    )
)

(define-public (withdraw-application (task-id uint))
    (let ((task (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND)))
        (asserts! (is-eq (get status task) "open") ERR_INVALID_STATUS)
        (asserts!
            (is-some (map-get? task-applications {
                task-id: task-id,
                applicant: tx-sender,
            }))
            ERR_NOT_AUTHORIZED
        )
        (map-delete task-applications {
            task-id: task-id,
            applicant: tx-sender,
        })
        (ok true)
    )
)

(define-public (rate-creator
        (task-id uint)
        (rating uint)
    )
    (let (
            (task (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND))
            (creator (get creator task))
        )
        (asserts!
            (is-eq tx-sender (unwrap! (get assignee task) ERR_TASK_NOT_ASSIGNED))
            ERR_NOT_AUTHORIZED
        )
        (asserts! (is-eq (get status task) "paid") ERR_INVALID_STATUS)
        (asserts! (<= rating u5) ERR_INVALID_RATING)
        (asserts! (>= rating u1) ERR_INVALID_RATING)
        (update-assignee-rating creator rating)
        (ok true)
    )
)
