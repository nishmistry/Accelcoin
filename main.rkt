;;"AAAAB3NzaC1yc2EAAAADAQABAAAAQQC9tsAgb00an/7SWjtyvSQqLynlXk60y0mlLdiiCgUzLbLdOv03leqkCysGuGUyYO/go3MBxFciQtIQvRD/DHcP"

(require "./crypto-extras.rkt")
(require "./hashtable-extras.rkt")
(require "./http-extras.rkt")
(require racket/string)

(define-struct transaction [serial unique-string sender-sig sender-key receiver-key amount])
;; A Transaction is a (make-transaction Nat String Signature PublicKey PublicKey Nat)
;;
;; (make-transaction serial unique-string sender-sig sender-key receiver-key amount) represents a
;; single transaction that moves amount accelcoin from sender-key to receiver-key.
;; Moreover:
;;
;; 1. The amount must be positive;
;; 2. The unique-string must be globally unique;
;; 2. The signature signs the string
;;      (string-append unique-string receiver-key ":" (number->string amount))
;;    with the private key corresponding to sender-key.
;; 3. the unique-string is a string that is unique to this transaction.

(define-struct block [transactions nonce miner-key])
;; A Block is a (make-block [List-of Transaction] Nat PublicKey)
;;
;; (make-block transactions nonce miner-key) represents a block of transactions mined by miner-key.
;; The transactions are processed left-to-right. Thus (first transactions) occurs before
;; (second transactions).

;; A Blockchain is a [NE-List-of Block]
;;
;; The first element of a Blockchain is the latest block and the last element is the first
;; block or the *genesis block*. The genesis block has zero transactions and all other blocks have
;; three or more transactions.

(define ALICE-PRIVATE-KEY
  (string-append
   "MIIBOgIBAAJBAMrPOfefdvowOwAplxY/NLkJFymyedikvwvsyhtQ98CawNXeKydg+WYD9YzQW1tIY5Ta1bqZhk5hpWGM4eusKxk"
   "CAwEAAQJAMtQW2hmsLu3xi4vg4uF6bDl8BaZGZWZ8vxdcW9ZCEZIEtnYGlkpwoG5YcUp3a39YRP+Nt2fA6bmPbvjmWAspkQIhAP"
   "odYjlh0p7P4QodsvQinMRp9Z8knfBmYeQpg/0otBMVAiEAz5Tjyw0Yanh6CCIvDRKQ+SvdTMvrJykIMyzmsWgYSPUCIEwGvIG2w"
   "3/0rnIVvvzIvKBTmQ7L4ZpedKkXGYDNa5dVAiAfRL5Lh911rFA1iXCs927/GaxsNQtnCrdBfjIB5zxBQQIhAO0ZN+PGdjJfbhiv"
   "Udgfx+DbrHkClSWT8SidILAbgQkd"))
(define BOB-PRIVATE-KEY
  (string-append
   "MIIBOwIBAAJBAKy4zO2w1HfXMNHSCYKuheD+5ZkAlHubePYNOVvi3gA/AQ1S0HcRFmTkzFz/SCp+0cZ3wErzHhKXmvgIrjLbdYM"
   "CAwEAAQJACBwBGyPTRfEnjKJk6erRxFeTZhSd5BPPoRXL3KGRNMesv5qct9QNbHA2ghjY4Z1gokwLgCViG88FvG0qMKGNSQIhAN"
   "duvtUGGvqeb+c6khwi60sf/3KMa082IjC3fe4RosJPAiEAzT8eusKDsL3q38i1o6E4pzUuW4oK0ta1BCGEdZn2kI0CIDb6bz8EC"
   "NyOlHZJL0J48t1ANDuydCxJ313ZZgzceVHnAiEApVA7vg1B6K9vaIPO2VbXvMW26wAKq7tH3WXpvJcf41kCIQCTv8zWOp8Dq3NK"
   "TdFZD28NCohpiEOAP3yMng9HhXcAqg=="))
(define CAROL-PRIVATE-KEY
  (string-append
   "MIICXAIBAAKBgQDV6LHGhFGhfQJWeUQOoehPc5G5Vj9y0uzZwe0TM0rGBrxfU2toyTeYT0uOwUgSyC6wWR7L8fKctM/x86wQcUT"
   "k5NtWrlagNkKwiehC0ws4aHi9WDI4IyJuTNv9vyeIeCVAiG83Z8osgW+66XI+5zDd9wrOEzeE/TuQR+qTV2H3CwIDAQABAoGAIj"
   "qdD+4mfdfaIuo+uLSxztzoaabiekZEPkgo3pSrl2qGhB5+JoNkUQwHRC2rkc3UosVwBySNNQQ97jKWyv7FDiySMmpm9P/c2x49Q"
   "uM6l3NhiR7G38LvHaIbxA9eHe+TKc2uyMc9vdklsRj4Yw8DSfUWavCGlkKx47UnrxK3PfECQQD1lWHc280i5qMGnFr7kYXR4CQ1"
   "g4Y0fajEm4yPP9RV9ivnBWoxe7rRAPgZQA9ptYUgZcVBchba3OAOH6Dv3XkJAkEA3vthaLKq3/QDSELSUtA3+Lq2eFdjNfnhKQO"
   "Uuf6qyqScdUN2/cHoIoqucCzQeNwQmLqQf4RhMIASswiUXN3YcwJAPLOiz9uIlfLaIv0sw/fRUvILISsUVg8lUwt7r8DANEs3yM"
   "+e0wJZR+XsbRlXdfKHKF3fZvDTU1+7BeKtffyJOQJAbu5ou4mHcPsYVu7Ha+OitN9Ov/fZp5S0646Ygx+rID1ciQoTPJMnRWfw+"
   "GWTIU16BEFsecQGBfbxVphCFyFW+QJBAMWKDB753ouUMa1J32jx86ANv4gAyXXX6hs5QDczDsCAW6RsCA3tiJTqifc3mhzvTPvI"
   "EDMh0NE/BSqt3C2D/jo=/SDJnoNEnooinoSDv+SDIOinonsdv/SDo"
   "inoinVOSNodnoe3onNodnoi92noNSDOIio90jsdjknioonwo"))
(define ALICE-PUBLIC-KEY (secret->public ALICE-PRIVATE-KEY))
(define BOB-PUBLIC-KEY (secret->public BOB-PRIVATE-KEY))
(define CAROL-PUBLIC-KEY (secret->public CAROL-PRIVATE-KEY))

;; Sends 100 accelcoins from Alice to Bob
(define EX-TRANSACTION-0
  (make-transaction
   0
   (unique-string)
   (make-signature (string-append BOB-PUBLIC-KEY ":" (number->string 100)) ALICE-PRIVATE-KEY)
   ALICE-PUBLIC-KEY
   BOB-PUBLIC-KEY
   100))

;; build-transaction: Nat String PrivateKey PublicKey Nat -> Transaction
;; (build-transaction serial unique-string sender-private-key receiver-public-key amount) builds a transaction
;; that sends amount from the sender to the receiver.
(define (build-transaction serial unique-string sender-private-key receiver-public-key amount)
  (make-transaction
   serial
   unique-string
   (make-signature (string-append unique-string receiver-public-key ":" (number->string amount))
                   sender-private-key)
   (secret->public sender-private-key)
   receiver-public-key
   amount))

(define EX-TRANSACTION-1 (build-transaction 1 (unique-string) ALICE-PRIVATE-KEY BOB-PUBLIC-KEY 50))
(define EX-TRANSACTION-2 (build-transaction 2 (unique-string) BOB-PRIVATE-KEY CAROL-PUBLIC-KEY 25))
(define EX-TRANSACTION-3 (build-transaction 3 (unique-string) ALICE-PRIVATE-KEY CAROL-PUBLIC-KEY 25))
(define EX-TRANSACTION-4 (build-transaction 4 (unique-string) CAROL-PRIVATE-KEY BOB-PUBLIC-KEY 10))
(define EX-TRANSACTION-5 (build-transaction 5 (unique-string) BOB-PRIVATE-KEY ALICE-PUBLIC-KEY 7))
;; Alice-32 Bob-28 Carol-40
;; Alice-32 Bob-128 Carol-40
(define EX-TRANSACTION-6 (build-transaction 6 (unique-string) BOB-PRIVATE-KEY CAROL-PUBLIC-KEY 75))
(define EX-TRANSACTION-7 (build-transaction 7 (unique-string) CAROL-PRIVATE-KEY ALICE-PUBLIC-KEY 12))
(define EX-TRANSACTION-8 (build-transaction 8 (unique-string) BOB-PRIVATE-KEY ALICE-PUBLIC-KEY 10))
(define EX-TRANSACTION-9 (build-transaction 9 (unique-string) ALICE-PRIVATE-KEY BOB-PUBLIC-KEY 30))
(define EX-TRANSACTION-10 (build-transaction 10 (unique-string) BOB-PRIVATE-KEY CAROL-PUBLIC-KEY 42))
(define EX-TRANSACTION-11
  (build-transaction 11 (unique-string) CAROL-PRIVATE-KEY ALICE-PUBLIC-KEY 25))
;; Alice-49 Bob-31 Carol-120
;; Alice-49 Bob-31 Carol-220

(define EX-TRANSACTION-INVALID
  (make-transaction
   11
   (unique-string)
   (make-signature (string-append ALICE-PUBLIC-KEY ":" (number->string 25)) BOB-PRIVATE-KEY)
   (secret->public CAROL-PRIVATE-KEY)
   ALICE-PUBLIC-KEY
   25))
(define EX-TRANSACTION-INVALID-2
  (make-transaction
   11
   (unique-string)
   (make-signature (string-append BOB-PUBLIC-KEY ":" (number->string 25)) CAROL-PRIVATE-KEY)
   (secret->public CAROL-PRIVATE-KEY)
   ALICE-PUBLIC-KEY
   25))

;; transaction->string : Transaction -> String
;; Serializes a transaction into a string with the format
;; "serial:transaction:unique-string:sender-sig:sender-key:receiver-key,amount"
(define (transaction->string tx)
  (string-append (number->string (transaction-serial tx))
                 ":transaction:"
                 (transaction-unique-string tx)
                 ":"
                 (transaction-sender-sig tx)
                 ":"
                 (transaction-sender-key tx)
                 ":"
                 (transaction-receiver-key tx)
                 ","
                 (number->string (transaction-amount tx))))

(define unique-string-ts-1 (unique-string))
(define unique-string-ts-2 (unique-string))

(check-expect
 (transaction->string
  (make-transaction 1 unique-string-ts-1 "sendersignature" "senderkey" "receiverkey" 100))
 (string-append "1:transaction:" unique-string-ts-1 ":sendersignature:senderkey:receiverkey,100"))
(check-expect (transaction->string (make-transaction 2 unique-string-ts-2 "sign" "skey" "rkey" 10032))
              (string-append "2:transaction:" unique-string-ts-2 ":sign:skey:rkey,10032"))

;; A genesis block where Alice starts the blockchain and receives the first mining reward.
(define EX-BLOCK-0
  (make-block '()
              8631727707325622792404128232286945630015639849891523695238049493932286431978
              ALICE-PUBLIC-KEY))

;; We are using EX-BLOCK-0 as the genesis block
(define EX-BLOCK-1
  (make-block
   (list EX-TRANSACTION-1 EX-TRANSACTION-2 EX-TRANSACTION-3 EX-TRANSACTION-4 EX-TRANSACTION-5)
   1
   BOB-PUBLIC-KEY))
;; EX-BLOCK-2 occurs after EX-BLOCK-1, therefore the current balance totals will exist
(define EX-BLOCK-2
  (make-block (list EX-TRANSACTION-6
                    EX-TRANSACTION-7
                    EX-TRANSACTION-8
                    EX-TRANSACTION-9
                    EX-TRANSACTION-10
                    EX-TRANSACTION-11)
              2
              CAROL-PUBLIC-KEY))
(define EX-BLOCK-INVALID (make-block (list EX-TRANSACTION-1 EX-TRANSACTION-2) 1 BOB-PUBLIC-KEY))
(define EX-BLOCK-INVALID-2
  (make-block (list EX-TRANSACTION-6
                    EX-TRANSACTION-7
                    EX-TRANSACTION-8
                    EX-TRANSACTION-9
                    EX-TRANSACTION-10
                    EX-TRANSACTION-INVALID)
              2
              CAROL-PUBLIC-KEY))
(define EX-BLOCK-INVALID-3
  (make-block (list EX-TRANSACTION-6
                    EX-TRANSACTION-7
                    EX-TRANSACTION-8
                    EX-TRANSACTION-9
                    EX-TRANSACTION-10
                    EX-TRANSACTION-INVALID-2)
              2
              CAROL-PUBLIC-KEY))

;; block-digest: Digest Block -> Digest
;; (block-digest prev-digest block) computes the digest of block, given the digest
;; of the previous block.
;;
;; The digest must be the digest of the following strings concatenated in order:
;;
;; 1. prev-digest as a string
;; 2. The transactions as strings (using transaction->string) concatenated in order
;; 3. The nonce as a string
(define (block-digest prev-dig bk)
  (local [;; append-all : Block -> String
          ;; Takes all transactions from a block and appends them into one string
          (define (append-all inner-bk)
            (foldr string-append "" (map transaction->string (block-transactions inner-bk))))]
         (digest (string-append (number->string prev-dig)
                                (append-all bk)
                                (number->string (block-nonce bk))))))

(check-expect (block-digest 0 EX-BLOCK-1)
              (digest (string-append "0"
                                     (transaction->string EX-TRANSACTION-1)
                                     (transaction->string EX-TRANSACTION-2)
                                     (transaction->string EX-TRANSACTION-3)
                                     (transaction->string EX-TRANSACTION-4)
                                     (transaction->string EX-TRANSACTION-5)
                                     "1")))
(check-expect (block-digest (block-digest 0 EX-BLOCK-1) EX-BLOCK-2)
              (digest (string-append (number->string (block-digest 0 EX-BLOCK-1))
                                     (transaction->string EX-TRANSACTION-6)
                                     (transaction->string EX-TRANSACTION-7)
                                     (transaction->string EX-TRANSACTION-8)
                                     (transaction->string EX-TRANSACTION-9)
                                     (transaction->string EX-TRANSACTION-10)
                                     (transaction->string EX-TRANSACTION-11)
                                     "2")))

(define DIGEST-LIMIT (expt 2 (* 8 30)))

;; mine-block : Digest PublicKey [List-of Transaction] Nat -> [Optional Block]
;; (mine-block prev-digest miner-public-key transactions trials)
;; tries to mine a block, but gives up after trials attempts.
;;
;; The produced block has a digest that is less than DIGEST-LIMIT.
(define (mine-block prev-digest miner-public-key transactions trials)
  (local [(define bk (make-block transactions (random 4294967087) miner-public-key))
          ;; tries to mine a block, but if it fails, it tries again with trial being one less.
          ;; Keeps recurring until block is mined of trial is equal to 0
          (define (mine-block-mini tr)
            (cond
              [(> tr 0)
               (if (< (block-digest prev-digest bk) DIGEST-LIMIT)
                   bk
                   (mine-block prev-digest miner-public-key transactions (- tr 1)))]
              [else #false]))]
         (mine-block-mini trials)))

(define EX-MINED-BLOCK-1
  (mine-block
   0
   BOB-PUBLIC-KEY
   (list EX-TRANSACTION-1 EX-TRANSACTION-2 EX-TRANSACTION-3 EX-TRANSACTION-4 EX-TRANSACTION-5)
   1000000))
(define EX-MINED-BLOCK-2
  (mine-block (block-digest 0 EX-MINED-BLOCK-1)
              CAROL-PUBLIC-KEY
              (list EX-TRANSACTION-6 EX-TRANSACTION-7 EX-TRANSACTION-8)
              1000000))
(define EX-MINED-BLOCK-3
  (mine-block (block-digest (block-digest 0 EX-MINED-BLOCK-1) EX-MINED-BLOCK-2)
              ALICE-PUBLIC-KEY
              (list EX-TRANSACTION-1 EX-TRANSACTION-2)
              1000000))
(define EX-MINED-BLOCK-INVALID
  (mine-block
   0
   ALICE-PUBLIC-KEY
   (list EX-TRANSACTION-1 EX-TRANSACTION-2 EX-TRANSACTION-3 EX-TRANSACTION-4 EX-TRANSACTION-5)
   100))
(define EX-MINED-BLOCK-BIG-TR
  (mine-block 0
              BOB-PUBLIC-KEY
              (list (build-transaction 1234 (unique-string) ALICE-PRIVATE-KEY BOB-PUBLIC-KEY 10000)
                    EX-TRANSACTION-1
                    EX-TRANSACTION-2)
              1000000))
(define EX-MINED-BLOCK-EMPTY-TR (mine-block 0 BOB-PUBLIC-KEY (list) 1000000))
(check-expect (< (block-digest 0 EX-MINED-BLOCK-1) DIGEST-LIMIT) #true)
(check-expect (< (block-digest (block-digest 0 EX-MINED-BLOCK-1) EX-MINED-BLOCK-2) DIGEST-LIMIT)
              #true)
(check-expect (false? EX-MINED-BLOCK-INVALID) #true)

(define unique-string-abo?-1 (unique-string))
(define unique-string-abo?-2 (unique-string))
(define unique-string-abo?-3 (unique-string))
(define unique-string-abo?-4 (unique-string))
(define unique-string-abo?-5 (unique-string))
(define unique-string-abo?-6 (unique-string))

;; hash-update : [Hash-table-of X Y] X (Y -> Y) Y
;; updates entry using function if present, else default

(define (hash-update h k upd def)
  (hash-set h k (if (hash-has-key? h k) (upd (hash-ref h k)) def)))

(check-expect (hash-update (make-hash (list)) "foo" add1 0) (make-hash (list (list "foo" 0))))
(check-expect (hash-update (make-hash (list (list "foo" 0) (list "bar" 0))) "foo" add1 0)
              (make-hash (list (list "foo" 1) (list "bar" 0))))

;; A Ledger is a [Hash-Table-of PublicKey Nat]
;; A ledger maps wallet IDs (public keys) to the number of accelcoins they have.

;; reward : PublicKey Ledger -> Ledger
;; Grants the miner the reward for mining a block.
(define (reward pk led)
  (hash-update led pk (λ (x) (+ 100 x)) 100))

(check-expect (reward "foo" (make-hash (list (list "foo" 2) (list "bar" 2) (list "baz" 1))))
              (make-hash (list (list "foo" 102) (list "bar" 2) (list "baz" 1))))

;; update-ledger/transaction: Transaction Ledger -> [Optional Ledger]
;; Updates the ledger with a single transaction. Produces #false if
;; the sender does not have enough accelcoin to send or if the transaction
;; amount is less than 1.
(define (update-ledger/transaction tx led)
  (if (and (hash-has-key? led (transaction-sender-key tx))
           (<= (transaction-amount tx) (hash-ref led (transaction-sender-key tx)))
           (>= (transaction-amount tx) 1))
      (hash-update
       (hash-update led (transaction-sender-key tx) (λ (x) (- x (transaction-amount tx))) 0)
       (transaction-receiver-key tx)
       (λ (x) (+ x (transaction-amount tx)))
       (transaction-amount tx))
      #f))

(check-expect
 (update-ledger/transaction (make-transaction 12324 unique-string-abo?-1 "qwert" "foo" "bar" 50)
                            (make-hash (list (list "foo" 100) (list "bar" 12) (list "baz" 134))))
 (make-hash (list (list "foo" 50) (list "bar" 62) (list "baz" 134))))

(check-expect
 (update-ledger/transaction (make-transaction 12324 unique-string-abo?-2 "qwert" "foo" "bar" 50)
                            (make-hash (list (list "foo" 40) (list "bar" 12) (list "baz" 134))))
 #f)

(check-expect
 (update-ledger/transaction (make-transaction 12324 unique-string-abo?-3 "qwert" "foo" "bar" 50)
                            (make-hash (list (list "foo" 100) (list "baz" 134))))
 (make-hash (list (list "foo" 50) (list "bar" 50) (list "baz" 134))))

(check-expect
 (update-ledger/transaction (make-transaction 12324 unique-string-abo?-4 "qwert" "foo" "bar" 0)
                            (make-hash (list (list "foo" 100) (list "baz" 134))))
 #false)

;; update-ledger/block : Block Ledger -> [Optional Ledger]
;; Updates the ledger with the transactions in a block, and rewards the miner.
(define (update-ledger/block bk led)
  (cond
    [(empty? (block-transactions bk)) (reward (block-miner-key bk) led)]
    [(false? (update-ledger/transaction (first (block-transactions bk)) led)) #false]
    [(empty? (rest (block-transactions bk)))
     (reward (block-miner-key bk) (update-ledger/transaction (first (block-transactions bk)) led))]
    [(cons? (rest (block-transactions bk)))
     (update-ledger/block
      (make-block (rest (block-transactions bk)) (block-nonce bk) (block-miner-key bk))
      (update-ledger/transaction (first (block-transactions bk)) led))]))

(check-expect
 (update-ledger/block
  EX-MINED-BLOCK-BIG-TR
  (make-hash (list (list ALICE-PUBLIC-KEY 100) (list BOB-PUBLIC-KEY 0) (list CAROL-PUBLIC-KEY 0))))
 #false)

(check-expect (update-ledger/block
               (make-block (list (make-transaction 12324 unique-string-abo?-1 "qwert" "foo" "bar" 50)
                                 (make-transaction 12324 unique-string-abo?-2 "qwert" "foo" "bar" 50))
                           2
                           "baz")
               (make-hash (list (list "foo" 100) (list "bar" 12) (list "baz" 134))))
              (make-hash (list (list "foo" 0) (list "bar" 112) (list "baz" 234))))

(check-expect
 (update-ledger/block (make-block (list) 2 "baz")
                      (make-hash (list (list "foo" 100) (list "bar" 12) (list "baz" 134))))
 (make-hash (list (list "foo" 100) (list "bar" 12) (list "baz" 234))))

(check-expect (update-ledger/block
               (make-block (list (make-transaction 12324 unique-string-abo?-3 "qwert" "foo" "bar" 75)
                                 (make-transaction 12324 unique-string-abo?-4 "qwert" "foo" "bar" 50))
                           2
                           "baz")
               (make-hash (list (list "foo" 100) (list "bar" 12) (list "baz" 134))))
              #false)

(check-expect (update-ledger/block
               (make-block (list (make-transaction 12324 unique-string-abo?-5 "qwert" "foo" "bar" 50)
                                 (make-transaction 12324 unique-string-abo?-6 "qwert" "foo" "bar" 75))
                           2
                           "baz")
               (make-hash (list (list "foo" 100) (list "bar" 12) (list "baz" 134))))
              #false)

(check-expect (update-ledger/block (make-block (list) 2 "baz") (make-hash (list)))
              (make-hash (list (list "baz" 100))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define my-secretkey
  (string-append
   "MIIBOwIBAAJBAL22wCBvTRqf/tJaO3K9JCovKeVeTrTLSaUt2KIKBTMtst06/TeV6qQLKwa4ZTJg7+CjcwHEVyJC0hC9"
   "EP8Mdw8CAwEAAQJBAJbAGmlrqBxJGOc0NlsVeyBeO+98ghReGZY9GRCh38Hq5M6isgEajC9PuEuiufing0V6Kn/p9Ac3n"
   "UbgYoSJiFECIQD3SZ8AmpOAVHevny0Emizub7RpnsgLW2ZamPWrzxZiZwIhAMRl2cFrE7PlZ7k6jM9L407qBwBU1KpFuFQFx"
   "z2t8W0ZAiEA5T5v06x4/yfPCJVEs5aF/si5dIzJIJYrzeMtJIhHVRMCIEKwiybgo0odBgGh3hquHDu5wDLem3BOSG9Pnv5UyHx"
   "RAiAW9bFbTwWTRHYulweCoeCtSI+eAyjo7W/oSMpV2Oo30A=="))
(define my-publickey (secret->public my-secretkey))

;; send-transaction: PrivateKey PublicKey Nat -> Boolean
;; (send-transaction sender-private-key receiver-public-key amount) sends a
;; transactions to the Accelchain broadcaster.
(define (send-transaction sender-private-key receiver-public-key amount)
  (local [(define str (unique-string))]
         (post-data
          "broadcaster.federico.codes"
          "/"
          (string-append
           "transaction:"
           str
           ":"
           (make-signature (string-append str receiver-public-key ":" (number->string amount))
                           sender-private-key)
           ":"
           (secret->public sender-private-key)
           ":"
           receiver-public-key
           ","
           (number->string amount)))))

(define-struct ValidatorState [ledger pending-transactions unique-strings prev-digest])
;; A ValidatorState is a (make-ValidatorState Ledger [Hash-Table-of String Transaction]
;;                        [Hash-Table-of String Boolean] Digest)
;;
;; It represents the current state of a blockchain validator, with ledger being the current ledger of the blockchain,
;; pending-transactions being a Hash Table of  pending transactions received but not yet mined in a block as the
;; values with their sender-public-keys as the keys, unique-strings being a Hash Table of all the unique strings of
;; the received transactions as the keys and #true as the values, and prev-digest being the digest of the most
;; recently validated block

(define vs-1
  (make-ValidatorState
   (make-hash (list (list ALICE-PUBLIC-KEY 100) (list BOB-PUBLIC-KEY 0) (list CAROL-PUBLIC-KEY 0)))
   (make-hash (list))
   (make-hash (list))
   0))
(define vs-2
  (make-ValidatorState
   (make-hash (list (list ALICE-PUBLIC-KEY 100) (list BOB-PUBLIC-KEY 0) (list CAROL-PUBLIC-KEY 0)))
   (make-hash (list (list 1 EX-TRANSACTION-1)
                    (list 2 EX-TRANSACTION-2)
                    (list 3 EX-TRANSACTION-3)
                    (list 4 EX-TRANSACTION-4)
                    (list 5 EX-TRANSACTION-5)
                    (list 6 EX-TRANSACTION-6)))
   (make-hash (list (list (transaction-unique-string EX-TRANSACTION-1) #true)
                    (list (transaction-unique-string EX-TRANSACTION-2) #true)
                    (list (transaction-unique-string EX-TRANSACTION-3) #true)
                    (list (transaction-unique-string EX-TRANSACTION-4) #true)
                    (list (transaction-unique-string EX-TRANSACTION-5) #true)
                    (list (transaction-unique-string EX-TRANSACTION-6) #true)))
   0))
(define vs-3
  (make-ValidatorState
   (make-hash (list (list ALICE-PUBLIC-KEY 32) (list BOB-PUBLIC-KEY 128) (list CAROL-PUBLIC-KEY 40)))
   (make-hash (list (list 6 EX-TRANSACTION-6)))
   (make-hash (list (list (transaction-unique-string EX-TRANSACTION-1) #true)
                    (list (transaction-unique-string EX-TRANSACTION-2) #true)
                    (list (transaction-unique-string EX-TRANSACTION-3) #true)
                    (list (transaction-unique-string EX-TRANSACTION-4) #true)
                    (list (transaction-unique-string EX-TRANSACTION-5) #true)
                    (list (transaction-unique-string EX-TRANSACTION-6) #true)))
   (block-digest 0 EX-MINED-BLOCK-1)))

;; handle-transaction : ValidatorState Transaction -> [Optional ValidatorState]
;; Consumes a ValidatorState and a transaction and determines whether the transaction is unique, has a valid
;; signature, and doesn't return false when passed into update-ledger/transaction with the current ledger.
;; If it does, it returns an updated ValidatorState with the transaction in the pending-transaction hash
;; and the unique string in the unique-strings hash, otherwise returns false.
(define (handle-transaction vs tr)
  (if (and (check-signature (transaction-sender-key tr)
                            (string-append (transaction-unique-string tr)
                                           (transaction-receiver-key tr)
                                           ":"
                                           (number->string (transaction-amount tr)))
                            (transaction-sender-sig tr))
           (not (hash-has-key? (ValidatorState-unique-strings vs) (transaction-unique-string tr)))
           (not (false? (update-ledger/transaction tr (ValidatorState-ledger vs)))))
      (make-ValidatorState
       (ValidatorState-ledger vs)
       (hash-set (ValidatorState-pending-transactions vs) (transaction-serial tr) tr)
       (hash-set (ValidatorState-unique-strings vs) (transaction-unique-string tr) #true)
       (ValidatorState-prev-digest vs))
      #false))

(check-expect
 (handle-transaction vs-1 EX-TRANSACTION-1)
 (make-ValidatorState
  (make-hash (list (list ALICE-PUBLIC-KEY 100) (list BOB-PUBLIC-KEY 0) (list CAROL-PUBLIC-KEY 0)))
  (make-hash (list (list 1 EX-TRANSACTION-1)))
  (make-hash (list (list (transaction-unique-string EX-TRANSACTION-1) #true)))
  0))

(check-expect (handle-transaction vs-3 EX-TRANSACTION-1) #false)

(check-expect (handle-transaction vs-1 EX-TRANSACTION-INVALID) #false)

;; handle-block : ValidatorState Block -> [Optional ValidatorState]
;; Consumes a ValidatorState and a block and determines whether the block is valid or not. If it is,
;; it returns an updated ValidatorState with the ledger updated to reflect the new transactions and
;; prev-digest updated to be the new block's digest, and it removes the transactions that are in both
;; the block and ValidatorState-pending-transactions. Otherwise, it returns false
(define (handle-block vs bk)
  (if (and (< (block-digest (ValidatorState-prev-digest vs) bk) DIGEST-LIMIT)
           (>= (length (block-transactions bk)) 3)
           (andmap
            (λ (tr) (hash-has-key? (ValidatorState-pending-transactions vs) (transaction-serial tr)))
            (block-transactions bk))
           (not (false? (update-ledger/block bk (ValidatorState-ledger vs)))))
      (make-ValidatorState
       (update-ledger/block bk (ValidatorState-ledger vs))
       (local [(define (tr-update pt trs)
                 (cond
                   [(empty? trs) pt]
                   [(cons? trs)
                    (hash-remove (tr-update pt (rest trs)) (transaction-serial (first trs)))]))]
              (tr-update (ValidatorState-pending-transactions vs) (block-transactions bk)))
       (ValidatorState-unique-strings vs)
       (block-digest (ValidatorState-prev-digest vs) bk))
      #false))

(check-expect
 (handle-block vs-2 EX-MINED-BLOCK-1)
 (make-ValidatorState
  (make-hash (list (list ALICE-PUBLIC-KEY 32) (list BOB-PUBLIC-KEY 128) (list CAROL-PUBLIC-KEY 40)))
  (make-hash (list (list 6 EX-TRANSACTION-6)))
  (make-hash (list (list (transaction-unique-string EX-TRANSACTION-1) #true)
                   (list (transaction-unique-string EX-TRANSACTION-2) #true)
                   (list (transaction-unique-string EX-TRANSACTION-3) #true)
                   (list (transaction-unique-string EX-TRANSACTION-4) #true)
                   (list (transaction-unique-string EX-TRANSACTION-5) #true)
                   (list (transaction-unique-string EX-TRANSACTION-6) #true)))
  (block-digest 0 EX-MINED-BLOCK-1)))

(check-expect (handle-block vs-1 EX-MINED-BLOCK-1) #false)

(check-expect (handle-block vs-2 EX-MINED-BLOCK-BIG-TR) #false)

(check-expect (handle-block vs-2 EX-MINED-BLOCK-EMPTY-TR) #false)

(define initial-state
  (make-ValidatorState (make-hash (list (list (string-append "AAAAB3NzaC1yc2EAAAADAQABAAAAQQ"
                                                             "DbXz4rfbrRrXYQJbwuCkIyIsccHRpx"
                                                             "hxqxgKeneVF4eUXof6e2nLvdXkGA0Y6"
                                                             "uBAQ6N7qKxasVTR/2s1N2OBWF")
                                              100)))
                       (make-hash (list))
                       (make-hash (list))
                       0))

(define (go init-state)
  (blockchain-big-bang init-state [on-transaction handle-transaction] [on-block handle-block]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; filter-transactions : ValidatorState -> [List-of Transaction]
;; Creates a temporary ledger, and filters out all the transactions in the pending-transactions
;; that return false from update-ledger/transaction, while updating the temporary ledger.
(define (filter-transactions st)
  (local [(define txs (ValidatorState-pending-transactions st)) (define txs-values (hash-values txs))]
         (first (foldl (lambda (tx acc)
                         (local [(define lst (first acc))
                                 (define ledger (second acc))
                                 (define updated-ledger (update-ledger/transaction tx ledger))]
                                (if (false? updated-ledger) acc (list (cons tx lst) updated-ledger))))
                       (list '() (ValidatorState-ledger st))
                       txs-values))))

;; mine+validate : ValidatorState PublicKey Number -> Boolean
;;
;; (mine+validate state miner-key retries)
;;
;; Uses mine-block (from Part 1) to mine the pending transactions in
;; the validator state.
;;
;; Produces #false if the retries are exhausted or if the number of pending
;; transactions is less than three.
;;
;; If mining succeeds, sends the serialized block using post-data and produces
;; #true.
(define (mine+validate state miner-key retries)
  (local
   [;; block->string : Block -> String
    ;; Serializes a block into a string with the format.
    (define filtered-transactions (filter-transactions state))
    (define (block->string blk)
      (local [(define transactions (block-transactions blk))
              (define transaction-strings
                (map (lambda (t) (string-replace (transaction->string t) ":" ";")) transactions))
              (define transaction-string (string-join transaction-strings ":"))]
             (format "block:~a:~a:~a" (block-nonce blk) (block-miner-key blk) transaction-string)))]
   (cond
     [(< (length filtered-transactions) 3) #false]
     [else
      (local ((define mined-block
                (mine-block (ValidatorState-prev-digest state)
                            miner-key
                            (list (first filtered-transactions)
                                  (second filtered-transactions)
                                  (third filtered-transactions))
                            retries)))
             (if (not (false? mined-block))
                 ;(post-data "accelchain.api.breq.dev" "/"  (block->string mined-block))
                 (post-data "broadcaster.federico.codes" "/" (block->string mined-block))
                 #false))])))

;; go-miner : ValidatorState PublicId Number -> ValidatorState
;;
;; (go-miner state miner-key retries) mines the pending transactions in state
;; uses `go` to validate the current blockchain, and then recurs indefinitely.
(define (go-miner state miner-id retries)
  (local [(define next-state (go state))
          (define x (displayln (hash-ref (ValidatorState-ledger next-state) my-publickey)))
          (define mine (mine+validate state miner-id retries))]
         (go-miner next-state miner-id retries)))
