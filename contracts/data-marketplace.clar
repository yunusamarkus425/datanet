;; DataNet Data Marketplace Contract
;; Handles data listings, purchases, and marketplace operations for tokenized data sales

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-unauthorized (err u202))
(define-constant err-insufficient-payment (err u203))
(define-constant err-invalid-data (err u204))
(define-constant err-listing-inactive (err u205))
(define-constant err-already-purchased (err u206))
(define-constant err-access-expired (err u207))
(define-constant err-invalid-price (err u208))
(define-constant err-marketplace-paused (err u209))
(define-constant err-invalid-category (err u210))
(define-constant err-listing-fee-required (err u211))

;; Marketplace configuration
(define-constant platform-fee-rate u250) ;; 2.5% (basis points)
(define-constant max-title-length u100)
(define-constant max-description-length u500)
(define-constant max-category-length u50)
(define-constant listing-fee u100) ;; 1.00 DNT
(define-constant min-data-price u500) ;; 5.00 DNT minimum
(define-constant subscription-duration-blocks u10080) ;; ~70 days

;; Data structures
(define-map data-listings uint {
    id: uint,
    provider: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    category: (string-ascii 50),
    price: uint,
    access-type: (string-ascii 20),
    data-hash: (buff 32),
    is-active: bool,
    created-at: uint,
    updated-at: uint,
    total-sales: uint,
    revenue-earned: uint
})

(define-map access-records {buyer: principal, data-id: uint} {
    purchased-at: uint,
    expires-at: (optional uint),
    access-granted: bool,
    payment-amount: uint
})

(define-map provider-stats principal {
    total-listings: uint,
    active-listings: uint,
    total-sales: uint,
    total-revenue: uint,
    reputation-score: uint,
    last-activity: uint
})

(define-map category-listings (string-ascii 50) (list 100 uint))
(define-map provider-earnings principal uint)
(define-map marketplace-fees principal uint)

;; Data variables
(define-data-var next-listing-id uint u1)
(define-data-var marketplace-paused bool false)
(define-data-var total-listings uint u0)
(define-data-var total-sales uint u0)
(define-data-var platform-revenue uint u0)
(define-data-var token-manager-contract principal .token-manager)

;; Valid categories
(define-constant valid-categories (list 
    "finance" "healthcare" "technology" "marketing" "research" 
    "education" "entertainment" "real-estate" "automotive" "other"))

;; Valid access types
(define-constant valid-access-types (list "one-time" "subscription" "unlimited"))

;; Read-only functions

(define-read-only (get-listing (listing-id uint))
    (map-get? data-listings listing-id))

(define-read-only (get-access-record (buyer principal) (data-id uint))
    (map-get? access-records {buyer: buyer, data-id: data-id}))

(define-read-only (get-provider-stats (provider principal))
    (default-to 
        {total-listings: u0, active-listings: u0, total-sales: u0, 
         total-revenue: u0, reputation-score: u0, last-activity: u0}
        (map-get? provider-stats provider)))

(define-read-only (get-provider-earnings (provider principal))
    (default-to u0 (map-get? provider-earnings provider)))

(define-read-only (get-total-listings)
    (var-get total-listings))

(define-read-only (get-total-sales)
    (var-get total-sales))

(define-read-only (get-platform-revenue)
    (var-get platform-revenue))

(define-read-only (is-marketplace-paused)
    (var-get marketplace-paused))

(define-read-only (get-category-listings (category (string-ascii 50)))
    (default-to (list) (map-get? category-listings category)))

(define-read-only (is-valid-category (category (string-ascii 50)))
    (or (is-eq category "finance")
        (is-eq category "healthcare")
        (is-eq category "technology")
        (is-eq category "marketing")
        (is-eq category "research")
        (is-eq category "education")
        (is-eq category "entertainment")
        (is-eq category "real-estate")
        (is-eq category "automotive")
        (is-eq category "other")))

(define-read-only (is-valid-access-type (access-type (string-ascii 20)))
    (or (is-eq access-type "one-time")
        (is-eq access-type "subscription")
        (is-eq access-type "unlimited")))

(define-read-only (calculate-platform-fee (price uint))
    (/ (* price platform-fee-rate) u10000))

(define-read-only (calculate-provider-payment (price uint))
    (- price (calculate-platform-fee price)))

(define-read-only (has-valid-access (buyer principal) (data-id uint))
    (let ((access-info (map-get? access-records {buyer: buyer, data-id: data-id})))
        (match access-info
            record (let ((is-granted (get access-granted record))
                        (expires-at (get expires-at record)))
                    (and is-granted
                         (match expires-at
                             expiry (> expiry stacks-block-height)
                             true)))
            false)))

;; Private functions

(define-private (is-owner)
    (is-eq tx-sender contract-owner))

(define-private (check-not-paused)
    (ok (asserts! (not (var-get marketplace-paused)) err-marketplace-paused)))

(define-private (update-provider-stats (provider principal) (listing-delta int) (sale-delta uint) (revenue-delta uint))
    (let ((current-stats (get-provider-stats provider)))
        (map-set provider-stats provider {
            total-listings: (if (> listing-delta 0) 
                              (+ (get total-listings current-stats) (to-uint listing-delta))
                              (get total-listings current-stats)),
            active-listings: (+ (get active-listings current-stats) (to-uint listing-delta)),
            total-sales: (+ (get total-sales current-stats) sale-delta),
            total-revenue: (+ (get total-revenue current-stats) revenue-delta),
            reputation-score: (get reputation-score current-stats), ;; Updated separately
            last-activity: stacks-block-height
        })))

(define-private (add-to-category (category (string-ascii 50)) (listing-id uint))
    (let ((current-list (default-to (list) (map-get? category-listings category))))
        (ok (map-set category-listings category (unwrap! (as-max-len? (append current-list listing-id) u100) (err u999))))))

;; Administrative functions

(define-public (pause-marketplace)
    (begin
        (asserts! (is-owner) err-owner-only)
        (var-set marketplace-paused true)
        (ok true)))

(define-public (unpause-marketplace)
    (begin
        (asserts! (is-owner) err-owner-only)
        (var-set marketplace-paused false)
        (ok true)))

(define-public (set-token-manager (new-token-manager principal))
    (begin
        (asserts! (is-owner) err-owner-only)
        (var-set token-manager-contract new-token-manager)
        (ok true)))

(define-public (withdraw-platform-fees)
    (let ((platform-earnings (var-get platform-revenue)))
        (asserts! (is-owner) err-owner-only)
        (asserts! (> platform-earnings u0) err-not-found)
        
        ;; Transfer platform fees to owner
        (try! (contract-call? .token-manager marketplace-transfer platform-earnings (as-contract tx-sender) tx-sender))
        (var-set platform-revenue u0)
        
        (print {action: "withdraw-platform-fees", amount: platform-earnings, recipient: tx-sender})
        (ok platform-earnings)))

;; Core marketplace functions

(define-public (list-data (title (string-ascii 100)) 
                         (description (string-ascii 500))
                         (category (string-ascii 50))
                         (price uint)
                         (access-type (string-ascii 20))
                         (data-hash (buff 32)))
    (let ((listing-id (var-get next-listing-id))
          (provider tx-sender))
        
        (try! (check-not-paused))
        (asserts! (is-valid-category category) err-invalid-category)
        (asserts! (is-valid-access-type access-type) err-invalid-data)
        (asserts! (>= price min-data-price) err-invalid-price)
        (asserts! (> (len title) u0) err-invalid-data)
        (asserts! (> (len description) u0) err-invalid-data)
        
        ;; Charge listing fee
        (try! (contract-call? .token-manager marketplace-transfer listing-fee provider (as-contract tx-sender)))
        
        ;; Create listing
        (map-set data-listings listing-id {
            id: listing-id,
            provider: provider,
            title: title,
            description: description,
            category: category,
            price: price,
            access-type: access-type,
            data-hash: data-hash,
            is-active: true,
            created-at: stacks-block-height,
            updated-at: stacks-block-height,
            total-sales: u0,
            revenue-earned: u0
        })
        
        ;; Update tracking variables
        (var-set next-listing-id (+ listing-id u1))
        (var-set total-listings (+ (var-get total-listings) u1))
        (var-set platform-revenue (+ (var-get platform-revenue) listing-fee))
        
        ;; Update provider stats and category
        (update-provider-stats provider 1 u0 u0)
        (try! (add-to-category category listing-id))
        
        (print {action: "list-data", listing-id: listing-id, provider: provider, title: title, price: price})
        (ok listing-id)))

(define-public (update-data-price (listing-id uint) (new-price uint))
    (let ((listing (unwrap! (map-get? data-listings listing-id) err-not-found)))
        (try! (check-not-paused))
        (asserts! (is-eq tx-sender (get provider listing)) err-unauthorized)
        (asserts! (get is-active listing) err-listing-inactive)
        (asserts! (>= new-price min-data-price) err-invalid-price)
        
        (map-set data-listings listing-id (merge listing {
            price: new-price,
            updated-at: stacks-block-height
        }))
        
        (print {action: "update-price", listing-id: listing-id, old-price: (get price listing), new-price: new-price})
        (ok true)))

(define-public (deactivate-listing (listing-id uint))
    (let ((listing (unwrap! (map-get? data-listings listing-id) err-not-found)))
        (try! (check-not-paused))
        (asserts! (is-eq tx-sender (get provider listing)) err-unauthorized)
        (asserts! (get is-active listing) err-listing-inactive)
        
        (map-set data-listings listing-id (merge listing {
            is-active: false,
            updated-at: stacks-block-height
        }))
        
        ;; Update provider stats
        (update-provider-stats (get provider listing) -1 u0 u0)
        
        (print {action: "deactivate-listing", listing-id: listing-id, provider: (get provider listing)})
        (ok true)))

(define-public (purchase-data-access (listing-id uint))
    (let ((listing (unwrap! (map-get? data-listings listing-id) err-not-found))
          (buyer tx-sender)
          (price (get price listing))
          (platform-fee (calculate-platform-fee price))
          (provider-payment (calculate-provider-payment price))
          (expires-at (if (is-eq (get access-type listing) "subscription")
                         (some (+ stacks-block-height subscription-duration-blocks))
                         none)))
        
        (try! (check-not-paused))
        (asserts! (get is-active listing) err-listing-inactive)
        (asserts! (is-none (map-get? access-records {buyer: buyer, data-id: listing-id})) err-already-purchased)
        
        ;; Transfer tokens
        (try! (contract-call? .token-manager marketplace-transfer price buyer (as-contract tx-sender)))
        (try! (contract-call? .token-manager marketplace-transfer provider-payment (as-contract tx-sender) (get provider listing)))
        
        ;; Create access record
        (map-set access-records {buyer: buyer, data-id: listing-id} {
            purchased-at: stacks-block-height,
            expires-at: expires-at,
            access-granted: true,
            payment-amount: price
        })
        
        ;; Update listing stats
        (map-set data-listings listing-id (merge listing {
            total-sales: (+ (get total-sales listing) u1),
            revenue-earned: (+ (get revenue-earned listing) price),
            updated-at: stacks-block-height
        }))
        
        ;; Update global stats
        (var-set total-sales (+ (var-get total-sales) u1))
        (var-set platform-revenue (+ (var-get platform-revenue) platform-fee))
        
        ;; Update provider stats and earnings
        (update-provider-stats (get provider listing) 0 u1 provider-payment)
        (map-set provider-earnings (get provider listing) 
                 (+ (default-to u0 (map-get? provider-earnings (get provider listing))) provider-payment))
        
        (print {
            action: "purchase-data", 
            listing-id: listing-id, 
            buyer: buyer, 
            price: price,
            provider: (get provider listing),
            expires-at: expires-at
        })
        (ok true)))

(define-public (extend-subscription (listing-id uint))
    (let ((listing (unwrap! (map-get? data-listings listing-id) err-not-found))
          (access-info (unwrap! (map-get? access-records {buyer: tx-sender, data-id: listing-id}) err-not-found))
          (price (get price listing)))
        
        (try! (check-not-paused))
        (asserts! (get is-active listing) err-listing-inactive)
        (asserts! (is-eq (get access-type listing) "subscription") err-invalid-data)
        (asserts! (get access-granted access-info) err-access-expired)
        
        ;; Process payment
        (let ((platform-fee (calculate-platform-fee price))
              (provider-payment (calculate-provider-payment price)))
            
            (try! (contract-call? .token-manager marketplace-transfer price tx-sender (as-contract tx-sender)))
            (try! (contract-call? .token-manager marketplace-transfer provider-payment (as-contract tx-sender) (get provider listing)))
            
            ;; Extend access
            (let ((current-expiry (unwrap! (get expires-at access-info) err-invalid-data))
                  (new-expiry (+ current-expiry subscription-duration-blocks)))
                
                (map-set access-records {buyer: tx-sender, data-id: listing-id} (merge access-info {
                    expires-at: (some new-expiry)
                }))
                
                (print {action: "extend-subscription", listing-id: listing-id, buyer: tx-sender, new-expiry: new-expiry})
                (ok new-expiry)))))

(define-public (withdraw-earnings)
    (let ((earnings (default-to u0 (map-get? provider-earnings tx-sender))))
        (asserts! (> earnings u0) err-not-found)
        
        ;; Transfer earnings to provider
        (try! (contract-call? .token-manager marketplace-transfer earnings (as-contract tx-sender) tx-sender))
        (map-set provider-earnings tx-sender u0)
        
        (print {action: "withdraw-earnings", provider: tx-sender, amount: earnings})
        (ok earnings)))

;; Query functions

(define-public (get-data-details (listing-id uint))
    (let ((listing (unwrap! (map-get? data-listings listing-id) err-not-found)))
        (asserts! (get is-active listing) err-listing-inactive)
        (ok {
            id: (get id listing),
            title: (get title listing),
            description: (get description listing),
            category: (get category listing),
            price: (get price listing),
            access-type: (get access-type listing),
            provider: (get provider listing),
            created-at: (get created-at listing),
            total-sales: (get total-sales listing)
        })))

(define-public (verify-access (listing-id uint))
    (ok (has-valid-access tx-sender listing-id)))

(define-read-only (get-marketplace-stats)
    {
        total-listings: (var-get total-listings),
        total-sales: (var-get total-sales),
        platform-revenue: (var-get platform-revenue),
        is-paused: (var-get marketplace-paused)
    })

