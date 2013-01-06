(global-set-key (kbd "C-!") "∀")
(global-set-key (kbd "C-?") "∃")
(global-set-key (kbd "C-&") "∧")
(global-set-key (kbd "C-|") "∨")
(global-set-key (kbd "C->") "→")
(global-set-key (kbd "C-M->") "⇒")
(global-set-key (kbd "C-+") "⇔")
(global-set-key (kbd "C-M-+") "⁺")
(global-set-key (kbd "C-S-u") "∪")
(global-set-key (kbd "C-S-M-u") "𝕌")
(global-set-key (kbd "C-S-i") "∩")
(global-set-key (kbd "C-:") "∈")
(global-set-key (kbd "C-~") (lambda () (interactive) (insert "¬")))
(global-set-key (kbd "C-S-c") "⊆")
(global-set-key (kbd "C-Q") "≤")

(global-set-key (kbd "C-{") "⟦")
(global-set-key (kbd "C-}") "⟧")
(global-set-key (kbd "C-M-{") "⦃")
(global-set-key (kbd "C-M-}") "⦄")

;; Greek : C-S-<char> for lower case version of Greek <char>
;;         add the Meta modifier for upper case Greek letter.
(define-prefix-command 'hol-unicode-p-map)
(define-prefix-command 'hol-unicode-P-map)
(define-prefix-command 'hol-unicode-not-map)
(define-prefix-command 'hol-unicode-subscript-map)
(define-prefix-command 'hol-unicode-superscript-map)
(define-key global-map (kbd "C-S-p") 'hol-unicode-p-map)
(define-key global-map (kbd "C-M-S-p") 'hol-unicode-P-map)
(define-key global-map (kbd "C-M-|") 'hol-unicode-not-map)
(define-key global-map (kbd "C-M-_") 'hol-unicode-subscript-map)
(define-key global-map (kbd "C-M-^") 'hol-unicode-superscript-map)

(global-set-key (kbd "C-S-a") "α")
(global-set-key (kbd "C-S-b") "β")
(global-set-key (kbd "C-S-g") "γ")
(global-set-key (kbd "C-S-d") "δ")
(global-set-key (kbd "C-S-e") "ε")
(global-set-key (kbd "C-S-l") "λ")
(global-set-key (kbd "C-S-m") "μ")
(global-set-key (kbd "C-S-n") "ν")
(define-key hol-unicode-p-map "i" "π")
(global-set-key (kbd "C-S-o") "ω")
(global-set-key (kbd "C-S-r") "ρ")
(global-set-key (kbd "C-S-s") "σ")
(global-set-key (kbd "C-S-t") "τ")
(define-key hol-unicode-p-map "h" "φ")
(define-key hol-unicode-p-map "s" "ψ")

(global-set-key (kbd "C-S-M-g") "Γ")
(global-set-key (kbd "C-S-M-d") "Δ")
(global-set-key (kbd "C-S-M-l") "Λ")
(global-set-key (kbd "C-S-M-o") "Ω")
(define-key hol-unicode-P-map "i" "Π")
(define-key hol-unicode-P-map "h" "Φ")
(define-key hol-unicode-P-map "s" "Ψ")

(define-key hol-unicode-not-map "=" "≠")
(define-key hol-unicode-not-map ":" "∉")
(define-key hol-unicode-not-map "0" "∅")

(define-key hol-unicode-subscript-map "1" "₁")
(define-key hol-unicode-subscript-map "2" "₂")
(define-key hol-unicode-subscript-map "3" "₃")
(define-key hol-unicode-subscript-map "4" "₄")
(define-key hol-unicode-subscript-map "5" "₅")
(define-key hol-unicode-subscript-map "6" "₆")
(define-key hol-unicode-subscript-map "7" "₇")
(define-key hol-unicode-subscript-map "8" "₈")
(define-key hol-unicode-subscript-map "9" "₉")
(define-key hol-unicode-subscript-map "0" "₀")

(define-key hol-unicode-superscript-map "1" "¹")
(define-key hol-unicode-superscript-map "2" "²")
(define-key hol-unicode-superscript-map "3" "³")
(define-key hol-unicode-superscript-map "4" "⁴")
(define-key hol-unicode-superscript-map "5" "⁵")
(define-key hol-unicode-superscript-map "6" "⁶")
(define-key hol-unicode-superscript-map "7" "⁷")
(define-key hol-unicode-superscript-map "8" "⁸")
(define-key hol-unicode-superscript-map "9" "⁹")
(define-key hol-unicode-superscript-map "0" "⁰")
;; ₀ ₁ ₂ ₃ ₄ ₅ ₆ ₇ ₈ ₉ ₊ ₋ ₌
