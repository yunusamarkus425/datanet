;; DataNet Token Manager Contract
;; Manages the DNT (DataNet Token) economy for the tokenized data marketplace

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-transfer-failed (err u104))
(define-constant err-already-staked (err u105))
(define-constant err-not-staked (err u106))
(define-constant err-staking-period-not-complete (err u107))
(define-constant err-invalid-recipient (err u108))

;; Token configuration
(define-constant token-name "DataNet Token")
(define-constant token-symbol "DNT")
(define-constant token-decimals u2)
(define-constant initial-supply u1000000) ;; 10,000.00 DNT
(define-constant min-staking-amount u1000) ;; 10.00 DNT minimum
(define-constant staking-period-blocks u1440) ;; ~10 days worth of blocks
(define-constant reward-rate u5) ;; 5% annual reward rate

;; Data maps
(define-map token-balances principal uint)
(define-map token-supplies principal uint)
(define-map staking-data principal {
    amount: uint,
    start-block: uint,
    rewards-earned: uint,
    last-claim-block: uint
})
(define-map authorized-contracts principal bool)

;; Data variables
(define-data-var total-supply uint u0)
(define-data-var contract-paused bool false)
(define-data-var total-staked uint u0)
(define-data-var reward-pool uint u0)

;; Initialize contract
(begin
    (map-set token-balances contract-owner initial-supply)
    (var-set total-supply initial-supply)
    (var-set reward-pool (/ initial-supply u10)) ;; 10% of initial supply for rewards
)

;; Read-only functions

(define-read-only (get-name)
    (ok token-name))

(define-read-only (get-symbol)
    (ok token-symbol))

(define-read-only (get-decimals)
    (ok token-decimals))

(define-read-only (get-balance (account principal))
    (default-to u0 (map-get? token-balances account)))

(define-read-only (get-total-supply)
    (var-get total-supply))

(define-read-only (get-staking-info (account principal))
    (map-get? staking-data account))

(define-read-only (get-total-staked)
    (var-get total-staked))

(define-read-only (is-contract-authorized (contract principal))
    (default-to false (map-get? authorized-contracts contract)))

(define-read-only (calculate-staking-rewards (account principal))
    (let ((staking-info (map-get? staking-data account)))
        (match staking-info
            info (let ((blocks-staked (- stacks-block-height (get start-block info)))
                      (staked-amount (get amount info))
                      (annual-blocks u52560) ;; Approximate blocks per year
                      (reward-calculation (/ (* staked-amount reward-rate blocks-staked) (* u100 annual-blocks))))
                (+ (get rewards-earned info) reward-calculation))
            u0)))

(define-read-only (is-contract-paused)
    (var-get contract-paused))

;; Private functions

(define-private (is-owner)
    (is-eq tx-sender contract-owner))

(define-private (check-not-paused)
    (ok (asserts! (not (var-get contract-paused)) (err u109))))

;; Administrative functions

(define-public (pause-contract)
    (begin
        (asserts! (is-owner) err-owner-only)
        (var-set contract-paused true)
        (ok true)))

(define-public (unpause-contract)
    (begin
        (asserts! (is-owner) err-owner-only)
        (var-set contract-paused false)
        (ok true)))

(define-public (authorize-contract (contract principal))
    (begin
        (asserts! (is-owner) err-owner-only)
        (map-set authorized-contracts contract true)
        (ok true)))

(define-public (deauthorize-contract (contract principal))
    (begin
        (asserts! (is-owner) err-owner-only)
        (map-set authorized-contracts contract false)
        (ok true)))

;; Core token functions

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (try! (check-not-paused))
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (not (is-eq sender recipient)) err-invalid-recipient)
        (asserts! (>= (get-balance sender) amount) err-insufficient-balance)
        
        (try! (ft-transfer? dnt-token amount sender recipient))
        
        (map-set token-balances sender (- (get-balance sender) amount))
        (map-set token-balances recipient (+ (get-balance recipient) amount))
        
        (print {action: "transfer", sender: sender, recipient: recipient, amount: amount})
        (ok true)))

(define-public (transfer-tokens (amount uint) (recipient principal))
    (transfer amount tx-sender recipient none))

(define-public (mint-tokens (amount uint) (recipient principal))
    (begin
        (asserts! (is-owner) err-owner-only)
        (asserts! (> amount u0) err-invalid-amount)
        (try! (check-not-paused))
        
        (try! (ft-mint? dnt-token amount recipient))
        
        (map-set token-balances recipient (+ (get-balance recipient) amount))
        (var-set total-supply (+ (var-get total-supply) amount))
        
        (print {action: "mint", recipient: recipient, amount: amount})
        (ok true)))

(define-public (burn-tokens (amount uint))
    (begin
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (>= (get-balance tx-sender) amount) err-insufficient-balance)
        (try! (check-not-paused))
        
        (try! (ft-burn? dnt-token amount tx-sender))
        
        (map-set token-balances tx-sender (- (get-balance tx-sender) amount))
        (var-set total-supply (- (var-get total-supply) amount))
        
        (print {action: "burn", account: tx-sender, amount: amount})
        (ok true)))

;; Staking functions

(define-public (stake-tokens (amount uint))
    (let ((current-balance (get-balance tx-sender))
          (current-staking (map-get? staking-data tx-sender)))
        (try! (check-not-paused))
        (asserts! (>= amount min-staking-amount) err-invalid-amount)
        (asserts! (>= current-balance amount) err-insufficient-balance)
        (asserts! (is-none current-staking) err-already-staked)
        
        (map-set token-balances tx-sender (- current-balance amount))
        (map-set staking-data tx-sender {
            amount: amount,
            start-block: stacks-block-height,
            rewards-earned: u0,
            last-claim-block: stacks-block-height
        })
        (var-set total-staked (+ (var-get total-staked) amount))
        
        (print {action: "stake", account: tx-sender, amount: amount, block: stacks-block-height})
        (ok true)))

(define-public (unstake-tokens)
    (let ((staking-info (unwrap! (map-get? staking-data tx-sender) err-not-staked)))
        (try! (check-not-paused))
        (asserts! (>= (- stacks-block-height (get start-block staking-info)) staking-period-blocks) 
                 err-staking-period-not-complete)
        
        (let ((staked-amount (get amount staking-info))
              (total-rewards (calculate-staking-rewards tx-sender)))
            
            (map-delete staking-data tx-sender)
            (map-set token-balances tx-sender 
                    (+ (get-balance tx-sender) staked-amount total-rewards))
            (var-set total-staked (- (var-get total-staked) staked-amount))
            (var-set reward-pool (- (var-get reward-pool) total-rewards))
            
            (print {action: "unstake", account: tx-sender, amount: staked-amount, rewards: total-rewards})
            (ok {amount: staked-amount, rewards: total-rewards}))))

(define-public (claim-staking-rewards)
    (let ((staking-info (unwrap! (map-get? staking-data tx-sender) err-not-staked))
          (current-rewards (calculate-staking-rewards tx-sender))
          (claimable-rewards (- current-rewards (get rewards-earned staking-info))))
        
        (try! (check-not-paused))
        (asserts! (> claimable-rewards u0) err-invalid-amount)
        
        (map-set token-balances tx-sender (+ (get-balance tx-sender) claimable-rewards))
        (map-set staking-data tx-sender (merge staking-info {
            rewards-earned: current-rewards,
            last-claim-block: stacks-block-height
        }))
        (var-set reward-pool (- (var-get reward-pool) claimable-rewards))
        
        (print {action: "claim-rewards", account: tx-sender, amount: claimable-rewards})
        (ok claimable-rewards)))

;; Contract interaction functions for marketplace

(define-public (marketplace-transfer (amount uint) (from principal) (to principal))
    (begin
        (asserts! (is-contract-authorized contract-caller) err-owner-only)
        (try! (check-not-paused))
        (transfer amount from to none)))

(define-public (add-to-reward-pool (amount uint))
    (begin
        (asserts! (is-contract-authorized contract-caller) err-owner-only)
        (var-set reward-pool (+ (var-get reward-pool) amount))
        (ok true)))

;; Define fungible token
(define-fungible-token dnt-token)

;; title: token-manager
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

