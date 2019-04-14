open import Nat
open import Prelude
open import List
open import contexts

module core where
  -- types
  data typ : Set where
    _==>_ : typ → typ → typ
    ⟨_⟩   : List typ → typ
    D[_]  : Nat → typ

  -- arrow type constructors bind very tightly
  infixr 25  _==>_

  -- Expressions (Sketches)
  mutual
    record rule : Set where
      inductive
      constructor |C[_]_=>_
      field
        ctor   : Nat
        parm   : Nat
        branch : exp

    data exp : Set where
      ·λ_=>_         : Nat → exp → exp
      fix_⦇·λ_=>_·⦈  : Nat → Nat → exp → exp
      X[_]           : Nat → exp
      _∘_            : exp → exp → exp
      ⟨_⟩            : List exp → exp
      get[_th-of_]_  : Nat → Nat → exp → exp
      C[_]_          : Nat → exp → exp
      case_of⦃·_·⦄  : exp → List rule → exp
      ??[_]          : Nat → exp

  data hole-name-new : (e : exp) → (u : Nat) → Set where
    HNNLam  : ∀{x e u} → hole-name-new e u → hole-name-new (·λ x => e) u
    HNNFix  : ∀{x f e u} → hole-name-new e u → hole-name-new (fix f ⦇·λ x => e ·⦈) u
    HNNVar  : ∀{x u} → hole-name-new (X[ x ]) u
    HNNAp   : ∀{e1 e2 u} → hole-name-new e1 u → hole-name-new e2 u → hole-name-new (e1 ∘ e2) u
    HNNTup  : ∀{es u} → (∀{i} → (h : i < ∥ es ∥) → hole-name-new (es ⟦ i given h ⟧) u) → hole-name-new ⟨ es ⟩ u
    HNNGet  : ∀{i n e u} → hole-name-new e u → hole-name-new (get[ i th-of n ] e) u
    HNNCtor : ∀{c e u} → hole-name-new e u → hole-name-new (C[ c ] e) u
    HNNCase : ∀{e rules u} →
                hole-name-new e u →
                (∀{i} → (h : i < ∥ rules ∥) → hole-name-new (rule.branch (rules ⟦ i given h ⟧)) u) →
                hole-name-new (case e of⦃· rules ·⦄) u
    HNNHole : ∀{u' u} → u' ≠ u → hole-name-new (??[ u' ]) u

  -- two terms that do not share any hole names
  data holes-disjoint : (e1 : exp) → (e2 : exp) → Set where
    HDLam  : ∀{x e e'} → holes-disjoint e e' → holes-disjoint (·λ x => e) e'
    HDFix  : ∀{x f e e'} → holes-disjoint e e' → holes-disjoint (fix f ⦇·λ x => e ·⦈) e'
    HDVar  : ∀{x e'} → holes-disjoint (X[ x ]) e'
    HDAp   : ∀{e1 e2 e'} → holes-disjoint e1 e' → holes-disjoint e2 e' → holes-disjoint (e1 ∘ e2) e'
    HDTup  : ∀{es e'} → (∀{i} → (h : i < ∥ es ∥) → holes-disjoint (es ⟦ i given h ⟧) e') → holes-disjoint ⟨ es ⟩ e'
    HDGet  : ∀{i n e e'} → holes-disjoint e e' → holes-disjoint (get[ i th-of n ] e) e'
    HDCtor : ∀{c e e'} → holes-disjoint e e' → holes-disjoint (C[ c ] e) e'
    HDCase : ∀{e rules e'} →
               holes-disjoint e e' →
               (∀{i} → (h : i < ∥ rules ∥) → holes-disjoint (rule.branch (rules ⟦ i given h ⟧)) e') →
               holes-disjoint (case e of⦃· rules ·⦄) e'
    HDHole : ∀{u e'} → hole-name-new e' u → holes-disjoint (??[ u ]) e'

  tctx = typ ctx
  hctx = (tctx ∧ typ) ctx
  denv = Σ[ dctx ∈ tctx ctx ]
          ∀{d1 d2 cctx1 cctx2 c} →
            d1 ≠ d2 →
            (d1 , cctx1) ∈ dctx →
            (d2 , cctx2) ∈ dctx →
            dom cctx1 c →
            dom cctx2 c →
            ⊥

  data _,_,_⊢_::_ : hctx → denv → tctx → exp → typ → Set where
    TALam  : ∀{Δ Σ' Γ x e τ1 τ2} →
               x # Γ →
               Δ , Σ' , (Γ ,, (x , τ1)) ⊢ e :: τ2 →
               Δ , Σ' , Γ ⊢ ·λ x => e :: τ1 ==> τ2
    TAFix  : ∀{Δ Σ' Γ f x e τ1 τ2} →
               f # Γ →
               x # Γ →
               Δ , Σ' , (Γ ,, (f , τ1 ==> τ2) ,, (x , τ1)) ⊢ e :: τ2 →
               Δ , Σ' , Γ ⊢ fix f ⦇·λ x => e ·⦈ :: τ1 ==> τ2
    TAVar  : ∀{Δ Σ' Γ x τ} → (x , τ) ∈ Γ → Δ , Σ' , Γ ⊢ X[ x ] :: τ
    TAApp  : ∀{Δ Σ' Γ f arg τ1 τ2} →
               holes-disjoint f arg →
               Δ , Σ' , Γ ⊢ f :: τ1 ==> τ2 →
               Δ , Σ' , Γ ⊢ arg :: τ1 →
               Δ , Σ' , Γ ⊢ f ∘ arg :: τ2
    TATpl  : ∀{Δ Σ' Γ es τs} →
               ∥ es ∥ == ∥ τs ∥ →
               (∀{i j} →
                  (i<∥es∥ : i < ∥ es ∥) →
                  (j<∥es∥ : j < ∥ es ∥) →
                  i ≠ j →
                  holes-disjoint (es ⟦ i given i<∥es∥ ⟧) (es ⟦ j given j<∥es∥ ⟧)) →
               (∀{i} →
                  (i<∥es∥ : i < ∥ es ∥) →
                  (i<∥τs∥ : i < ∥ τs ∥) →
                  Δ , Σ' , Γ ⊢ es ⟦ i given i<∥es∥ ⟧ :: (τs ⟦ i given i<∥τs∥ ⟧)) →
               Δ , Σ' , Γ ⊢ ⟨ es ⟩ :: ⟨ τs ⟩
    TAGet  : ∀{Δ Σ' Γ i e τs} →
               (i<∥τs∥ : i < ∥ τs ∥) →
               Δ , Σ' , Γ ⊢ e :: ⟨ τs ⟩ →
               Δ , Σ' , Γ ⊢ get[ i th-of ∥ τs ∥ ] e :: (τs ⟦ i given i<∥τs∥ ⟧)
    TACtor : ∀{Δ Σ' Γ d cctx c e τ} →
               (d , cctx) ∈ π1 Σ' →
               (c , τ) ∈ cctx →
               Δ , Σ' , Γ ⊢ e :: τ →
               Δ , Σ' , Γ ⊢ C[ c ] e :: D[ d ]
    TACase : ∀{Δ Σ' Γ d cctx e rules τ} →
               (d , cctx) ∈ π1 Σ' →
               Δ , Σ' , Γ ⊢ e :: D[ d ] →
               (∀{c} →
                  dom cctx c →
                  -- There must be a rule for each constructor, i.e. case exhuastiveness
                  Σ[ i ∈ Nat ] ((i<∥rules∥ : i < ∥ rules ∥) → (rule.ctor (rules ⟦ i given i<∥rules∥ ⟧) == c))) →
               (∀{i ci xi ei} →
                  xi # Γ →
                  (i<∥rules∥ : i < ∥ rules ∥) →
                  |C[ ci ] xi => ei == rules ⟦ i given i<∥rules∥ ⟧ →
                  holes-disjoint ei e ∧
                  (∀{j} → (j<∥rules∥ : j < ∥ rules ∥) → i ≠ j → holes-disjoint ei (rule.branch (rules ⟦ j given j<∥rules∥ ⟧))) ∧
                  -- The constructor of each rule must be of the right datatype, and the branch must type-check
                  Σ[ τi ∈ typ ] ((ci , τi) ∈ cctx ∧ Δ , Σ' , (Γ ,, (xi , τi)) ⊢ ei :: τ)) →
               Δ , Σ' , Γ ⊢ case e of⦃· rules ·⦄ :: τ
    -- TODO we may have a problem with weakening
    TAHole : ∀{Δ Σ' Γ u τ} → (u , (Γ , τ)) ∈ Δ → Δ , Σ' , Γ ⊢ ??[ u ] :: τ

  mutual
    env : Set
    env = result ctx

    -- results - evaluation takes expressions to results, but results aren't necessarily final
    data result : Set where
      [_]λ_=>_         : env → Nat → exp → result
      [_]fix_⦇·λ_=>_·⦈ : env → Nat → Nat → exp → result
      ⟨_⟩              : List result → result
      C[_]_            : Nat → result → result
      [_]??[_]         : env → Nat → result
      _∘_              : result → result → result
      get[_th-of_]_    : Nat → Nat → result → result
      [_]case_of⦃·_·⦄ : env → result → List rule → result

  -- values are final and do not have holes
  data _value : result → Set where
    VLam : ∀{E x e} → ([ E ]λ x => e) value
    VFix : ∀{E f x e} → [ E ]fix f ⦇·λ x => e ·⦈ value
    VTpl : ∀{rs} → (∀{i} → (h : i < ∥ rs ∥) → (rs ⟦ i given h ⟧) value) → ⟨ rs ⟩ value
    VCon : ∀{c r} → r value → (C[ c ] r) value

  -- final results are those that cannot be evaluated further
  data _final : result → Set where
    FVal  : ∀{r} → r value → r final
    FTpl  : ∀{rs} → (∀{i} → (h : i < ∥ rs ∥) → (rs ⟦ i given h ⟧) final) → ⟨ rs ⟩ final
    FCon  : ∀{c r} → r final → (C[ c ] r) final
    FHole : ∀{E u} → [ E ]??[ u ] final
    FAp   : ∀{r1 r2} → r1 final → r2 final → (∀{E x e} → r1 ≠ ([ E ]λ x => e)) → (∀{E f x e} → r1 ≠ [ E ]fix f ⦇·λ x => e ·⦈) → (r1 ∘ r2) final
    FGet  : ∀{i n r} → r final → (∀{rs} → r ≠ ⟨ rs ⟩) → (get[ i th-of n ] r) final
    FCase : ∀{E r rules} → r final → (∀{c r'} → r ≠ (C[ c ] r')) → [ E ]case r of⦃· rules ·⦄ final

  -- Big step evaluation
  -- TODO : Change List ⊤ to K or List K or whatever
  data _⊢_⇒_⊣_ : env → exp → result → List ⊤ → Set where
    EFun             : ∀{E x e} → E ⊢ ·λ x => e ⇒ [ E ]λ x => e ⊣ []
    EFix             : ∀{E f x e} → E ⊢ fix f ⦇·λ x => e ·⦈ ⇒ [ E ]fix f ⦇·λ x => e ·⦈ ⊣ []
    EVar             : ∀{E x r} → (x , r) ∈ E → E ⊢ X[ x ] ⇒ r ⊣ []
    EHole            : ∀{E u} → E ⊢ ??[ u ] ⇒ [ E ]??[ u ] ⊣ []
    ETuple           : ∀{E es rs ks} →
                         ∥ es ∥ == ∥ rs ∥ →
                         ∥ es ∥ == ∥ ks ∥ →
                         -- TODO this should probably factored out somehow
                         (∀{i} →
                            (h : i < ∥ es ∥) →
                            (hr : i < ∥ rs ∥) →
                            (hk : i < ∥ ks ∥) →
                            E ⊢ es ⟦ i given h ⟧ ⇒ rs ⟦ i given hr ⟧ ⊣ (ks ⟦ i given hk ⟧)) →
                         E ⊢ ⟨ es ⟩ ⇒ ⟨ rs ⟩ ⊣ foldl _++_ [] ks
    ECtor            : ∀{E c e r k} → E ⊢ e ⇒ r ⊣ k → E ⊢ C[ c ] e ⇒ (C[ c ] r) ⊣ k
    EApp             : ∀{E e1 e2 Ef x ef kf r2 k2 r k} →
                         E ⊢ e1 ⇒ ([ Ef ]λ x => ef) ⊣ kf →
                         E ⊢ e2 ⇒ r2 ⊣ k2 →
                         (Ef ,, (x , r2)) ⊢ ef ⇒ r ⊣ k →
                         E ⊢ e1 ∘ e2 ⇒ r ⊣ kf ++ k2 ++ k
    EAppFix          : ∀{E e1 e2 Ef f x ef r1 k1 r2 k2 r k} →
                         r1 == [ Ef ]fix f ⦇·λ x => ef ·⦈ →
                         E ⊢ e1 ⇒ r1 ⊣ k1 →
                         E ⊢ e2 ⇒ r2 ⊣ k2 →
                         (Ef ,, (f , r1) ,, (x , r2)) ⊢ ef ⇒ r ⊣ k →
                         E ⊢ e1 ∘ e2 ⇒ r ⊣ k1 ++ k2 ++ k
    EAppUnfinished   : ∀{E e1 e2 r1 k1 r2 k2} →
                         E ⊢ e1 ⇒ r1 ⊣ k1 →
                         (∀{Ef x ef} → r1 ≠ ([ Ef ]λ x => ef)) →
                         (∀{Ef f x ef} → r1 ≠ [ Ef ]fix f ⦇·λ x => ef ·⦈) →
                         E ⊢ e2 ⇒ r2 ⊣ k2 →
                         E ⊢ e1 ∘ e2 ⇒ (r1 ∘ r2) ⊣ k1 ++ k2
    EGet             : ∀{E i e rs k} →
                         (h : i < ∥ rs ∥) →
                         E ⊢ e ⇒ ⟨ rs ⟩ ⊣ k →
                         E ⊢ get[ i th-of ∥ rs ∥ ] e ⇒ (rs ⟦ i given h ⟧) ⊣ k
    EGetUnfinished   : ∀{E i n e r k} → E ⊢ e ⇒ r ⊣ k → (∀{rs} → r ≠ ⟨ rs ⟩) → E ⊢ get[ i th-of n ] e ⇒ (get[ i th-of n ] r) ⊣ k
    EMatch           : ∀{E e rules j Cj xj ej r' k' r k} →
                         (h : j < ∥ rules ∥) →
                         |C[ Cj ] xj => ej == rules ⟦ j given h ⟧ →
                         E ⊢ e ⇒ (C[ Cj ] r') ⊣ k' →
                         (E ,, (xj , r')) ⊢ ej ⇒ r ⊣ k →
                         E ⊢ case e of⦃· rules ·⦄ ⇒ r ⊣ k' ++ k
    EMatchUnfinished : ∀{E e rules r k} →
                         E ⊢ e ⇒ r ⊣ k →
                         (∀{j e'} → r ≠ (C[ j ] e')) →
                         E ⊢ case e of⦃· rules ·⦄ ⇒ [ E ]case r of⦃· rules ·⦄ ⊣ k

    -- TODO metathm that evaluation always results in a final
    -- TODO metathm that holes-disjoint implies constraints-disjoint, and one that constraints produced by evaluation have index uniqueness

{- TODO

  -- todo : rename everything.

  -- the type of type contexts, i.e. Γs in the judegments below
  tctx : Set
  tctx = htyp ctx

  mutual
    -- identity substitution, substitition environments
    data env : Set where
      Id : (Γ : tctx) → env
      Subst : (d : ihexp) → (y : Nat) → env → env

    -- internal expressions
    data ihexp : Set where
      c         : ihexp
      X         : Nat → ihexp
      ·λ_[_]_   : Nat → htyp → ihexp → ihexp
      ⦇⦈⟨_⟩     : (Nat × env) → ihexp
      ⦇⌜_⌟⦈⟨_⟩    : ihexp → (Nat × env) → ihexp
      _∘_       : ihexp → ihexp → ihexp
      _⟨_⇒_⟩    : ihexp → htyp → htyp → ihexp
      _⟨_⇒⦇⦈⇏_⟩ : ihexp → htyp → htyp → ihexp
      ⟨_,_⟩   : ihexp → ihexp → ihexp
      fst     : ihexp → ihexp
      snd     : ihexp → ihexp


  -- convenient notation for chaining together two agreeable casts
  _⟨_⇒_⇒_⟩ : ihexp → htyp → htyp → htyp → ihexp
  d ⟨ t1 ⇒ t2 ⇒ t3 ⟩ = d ⟨ t1 ⇒ t2 ⟩ ⟨ t2 ⇒ t3 ⟩

  record paldef : Set where
    field
      expand : ihexp
      model-type : htyp
      expansion-type : htyp

  -- new outermost layer: a langauge exactly like hexp but also with palettes
  data pexp : Set where
    c       : pexp
    _·:_    : pexp → htyp → pexp
    X       : Nat → pexp
    ·λ      : Nat → pexp → pexp
    ·λ_[_]_ : Nat → htyp → pexp → pexp
    ⦇⦈[_]   : Nat → pexp
    ⦇⌜_⌟⦈[_]  : pexp → Nat → pexp
    _∘_     : pexp → pexp → pexp
    ⟨_,_⟩   : pexp → pexp → pexp
    fst     : pexp → pexp
    snd     : pexp → pexp
    -- new forms below
    let-pal_be_·in_ : Nat → paldef → pexp → pexp
    ap-pal : Nat → ihexp → (htyp × pexp) → pexp

  -- type consistency
  data _~_ : (t1 t2 : htyp) → Set where
    TCRefl  : {τ : htyp} → τ ~ τ
    TCHole1 : {τ : htyp} → τ ~ ⦇⦈
    TCHole2 : {τ : htyp} → ⦇⦈ ~ τ
    TCArr   : {τ1 τ2 τ1' τ2' : htyp} →
               τ1 ~ τ1' →
               τ2 ~ τ2' →
               τ1 ==> τ2 ~ τ1' ==> τ2'
    TCProd  : {τ1 τ2 τ1' τ2' : htyp} →
               τ1 ~ τ1' →
               τ2 ~ τ2' →
               (τ1 ⊗ τ2) ~ (τ1' ⊗ τ2')

  -- type inconsistency
  data _~̸_ : (τ1 τ2 : htyp) → Set where
    ICBaseArr1 : {τ1 τ2 : htyp} → b ~̸ τ1 ==> τ2
    ICBaseArr2 : {τ1 τ2 : htyp} → τ1 ==> τ2 ~̸ b
    ICArr1 : {τ1 τ2 τ3 τ4 : htyp} →
               τ1 ~̸ τ3 →
               τ1 ==> τ2 ~̸ τ3 ==> τ4
    ICArr2 : {τ1 τ2 τ3 τ4 : htyp} →
               τ2 ~̸ τ4 →
               τ1 ==> τ2 ~̸ τ3 ==> τ4
    ICBaseProd1 : {τ1 τ2 : htyp} → b ~̸ τ1 ⊗ τ2
    ICBaseProd2 : {τ1 τ2 : htyp} → τ1 ⊗ τ2 ~̸ b
    ICProdArr1 : {τ1 τ2 τ3 τ4 : htyp} →
                τ1 ==> τ2 ~̸ τ3 ⊗ τ4
    ICProdArr2 : {τ1 τ2 τ3 τ4 : htyp} →
                τ1 ⊗ τ2 ~̸ τ3 ==> τ4
    ICProd1 : {τ1 τ2 τ3 τ4 : htyp} →
               τ1 ~̸ τ3 →
               τ1 ⊗ τ2 ~̸ τ3 ⊗ τ4
    ICProd2 : {τ1 τ2 τ3 τ4 : htyp} →
               τ2 ~̸ τ4 →
               τ1 ⊗ τ2 ~̸ τ3 ⊗ τ4

  --- matching for arrows
  data _▸arr_ : htyp → htyp → Set where
    MAHole : ⦇⦈ ▸arr ⦇⦈ ==> ⦇⦈
    MAArr  : {τ1 τ2 : htyp} → τ1 ==> τ2 ▸arr τ1 ==> τ2

  -- matching for products
  data _▸prod_ : htyp → htyp → Set where
    MPHole : ⦇⦈ ▸prod ⦇⦈ ⊗ ⦇⦈
    MPProd  : {τ1 τ2 : htyp} → τ1 ⊗ τ2 ▸prod τ1 ⊗ τ2

  -- the type of hole contexts, i.e. Δs in the judgements
  hctx : Set
  hctx = (htyp ctx × htyp) ctx

  -- notation for a triple to match the CMTT syntax
  _::_[_] : Nat → htyp → tctx → (Nat × (tctx × htyp))
  u :: τ [ Γ ] = u , (Γ , τ)

  -- the hole name u does not appear in the term e
  data hole-name-new : (e : hexp) (u : Nat) → Set where
    HNConst : ∀{u} → hole-name-new c u
    HNAsc : ∀{e τ u} →
            hole-name-new e u →
            hole-name-new (e ·: τ) u
    HNVar : ∀{x u} → hole-name-new (X x) u
    HNLam1 : ∀{x e u} →
             hole-name-new e u →
             hole-name-new (·λ x e) u
    HNLam2 : ∀{x e u τ} →
             hole-name-new e u →
             hole-name-new (·λ x [ τ ] e) u
    HNHole : ∀{u u'} →
             u' ≠ u →
             hole-name-new (⦇⦈[ u' ]) u
    HNNEHole : ∀{u u' e} →
               u' ≠ u →
               hole-name-new e u →
               hole-name-new (⦇⌜ e ⌟⦈[ u' ]) u
    HNAp : ∀{ u e1 e2 } →
           hole-name-new e1 u →
           hole-name-new e2 u →
           hole-name-new (e1 ∘ e2) u
    HNFst  : ∀{ u e } →
           hole-name-new e u →
           hole-name-new (fst e) u
    HNSnd  : ∀{ u e } →
           hole-name-new e u →
           hole-name-new (snd e) u
    HNPair : ∀{ u e1 e2 } →
           hole-name-new e1 u →
           hole-name-new e2 u →
           hole-name-new ⟨ e1 , e2 ⟩ u

  -- two terms that do not share any hole names
  data holes-disjoint : (e1 : hexp) → (e2 : hexp) → Set where
    HDConst : ∀{e} → holes-disjoint c e
    HDAsc : ∀{e1 e2 τ} → holes-disjoint e1 e2 → holes-disjoint (e1 ·: τ) e2
    HDVar : ∀{x e} → holes-disjoint (X x) e
    HDLam1 : ∀{x e1 e2} → holes-disjoint e1 e2 → holes-disjoint (·λ x e1) e2
    HDLam2 : ∀{x e1 e2 τ} → holes-disjoint e1 e2 → holes-disjoint (·λ x [ τ ] e1) e2
    HDHole : ∀{u e2} → hole-name-new e2 u → holes-disjoint (⦇⦈[ u ]) e2
    HDNEHole : ∀{u e1 e2} → hole-name-new e2 u → holes-disjoint e1 e2 → holes-disjoint (⦇⌜ e1 ⌟⦈[ u ]) e2
    HDAp :  ∀{e1 e2 e3} → holes-disjoint e1 e3 → holes-disjoint e2 e3 → holes-disjoint (e1 ∘ e2) e3
    HDFst  : ∀{e1 e2} → holes-disjoint e1 e2 → holes-disjoint (fst e1) e2
    HDSnd  : ∀{e1 e2} → holes-disjoint e1 e2 → holes-disjoint (snd e1) e2
    HDPair : ∀{e1 e2 e3} → holes-disjoint e1 e3 → holes-disjoint e2 e3 → holes-disjoint ⟨ e1 , e2 ⟩ e3

  -- bidirectional type checking judgements for hexp
  mutual
    -- synthesis
    data _⊢_=>_ : (Γ : tctx) (e : hexp) (τ : htyp) → Set where
      SConst  : {Γ : tctx} → Γ ⊢ c => b
      SAsc    : {Γ : tctx} {e : hexp} {τ : htyp} →
                 Γ ⊢ e <= τ →
                 Γ ⊢ (e ·: τ) => τ
      SVar    : {Γ : tctx} {τ : htyp} {x : Nat} →
                 (x , τ) ∈ Γ →
                 Γ ⊢ X x => τ
      SAp     : {Γ : tctx} {e1 e2 : hexp} {τ τ1 τ2 : htyp} →
                 holes-disjoint e1 e2 →
                 Γ ⊢ e1 => τ1 →
                 τ1 ▸arr τ2 ==> τ →
                 Γ ⊢ e2 <= τ2 →
                 Γ ⊢ (e1 ∘ e2) => τ
      SEHole  : {Γ : tctx} {u : Nat} → Γ ⊢ ⦇⦈[ u ] => ⦇⦈
      SNEHole : {Γ : tctx} {e : hexp} {τ : htyp} {u : Nat} →
                 hole-name-new e u →
                 Γ ⊢ e => τ →
                 Γ ⊢ ⦇⌜ e ⌟⦈[ u ] => ⦇⦈
      SLam    : {Γ : tctx} {e : hexp} {τ1 τ2 : htyp} {x : Nat} →
                 x # Γ →
                 (Γ ,, (x , τ1)) ⊢ e => τ2 →
                 Γ ⊢ ·λ x [ τ1 ] e => τ1 ==> τ2
      SFst    : ∀{ e τ τ1 τ2 Γ} →
                Γ ⊢ e => τ →
                τ ▸prod τ1 ⊗ τ2 →
                Γ ⊢ fst e => τ1
      SSnd    : ∀{ e τ τ1 τ2 Γ} →
                Γ ⊢ e => τ →
                τ ▸prod τ1 ⊗ τ2 →
                Γ ⊢ snd e => τ2
      SPair   : ∀{ e1 e2 τ1 τ2 Γ} →
                holes-disjoint e1 e2 →
                Γ ⊢ e1 => τ1 →
                Γ ⊢ e2 => τ2 →
                Γ ⊢ ⟨ e1 , e2 ⟩ => τ1 ⊗ τ2

    -- analysis
    data _⊢_<=_ : (Γ : htyp ctx) (e : hexp) (τ : htyp) → Set where
      ASubsume : {Γ : tctx} {e : hexp} {τ τ' : htyp} →
                 Γ ⊢ e => τ' →
                 τ ~ τ' →
                 Γ ⊢ e <= τ
      ALam : {Γ : tctx} {e : hexp} {τ τ1 τ2 : htyp} {x : Nat} →
                 x # Γ →
                 τ ▸arr τ1 ==> τ2 →
                 (Γ ,, (x , τ1)) ⊢ e <= τ2 →
                 Γ ⊢ (·λ x e) <= τ

  -- those types without holes
  data _tcomplete : htyp → Set where
    TCBase : b tcomplete
    TCArr : ∀{τ1 τ2} → τ1 tcomplete → τ2 tcomplete → (τ1 ==> τ2) tcomplete
    TCProd : ∀{τ1 τ2} → τ1 tcomplete → τ2 tcomplete → (τ1 ⊗ τ2) tcomplete

  -- those external expressions without holes
  data _ecomplete : hexp → Set where
    ECConst : c ecomplete
    ECAsc : ∀{τ e} → τ tcomplete → e ecomplete → (e ·: τ) ecomplete
    ECVar : ∀{x} → (X x) ecomplete
    ECLam1 : ∀{x e} → e ecomplete → (·λ x e) ecomplete
    ECLam2 : ∀{x e τ} → e ecomplete → τ tcomplete → (·λ x [ τ ] e) ecomplete
    ECAp : ∀{e1 e2} → e1 ecomplete → e2 ecomplete → (e1 ∘ e2) ecomplete
    ECFst : ∀{e} → e ecomplete → (fst e) ecomplete
    ECSnd : ∀{e} → e ecomplete → (snd e) ecomplete
    ECPair : ∀{e1 e2} → e1 ecomplete → e2 ecomplete → ⟨ e1 , e2 ⟩ ecomplete

  -- those internal expressions without holes
  data _dcomplete : ihexp → Set where
    DCVar : ∀{x} → (X x) dcomplete
    DCConst : c dcomplete
    DCLam : ∀{x τ d} → d dcomplete → τ tcomplete → (·λ x [ τ ] d) dcomplete
    DCAp : ∀{d1 d2} → d1 dcomplete → d2 dcomplete → (d1 ∘ d2) dcomplete
    DCCast : ∀{d τ1 τ2} → d dcomplete → τ1 tcomplete → τ2 tcomplete → (d ⟨ τ1 ⇒ τ2 ⟩) dcomplete
    DCFst : ∀{d} → d dcomplete → (fst d) dcomplete
    DCSnd : ∀{d} → d dcomplete → (snd d) dcomplete
    DCPair : ∀{d1 d2} → d1 dcomplete → d2 dcomplete → ⟨ d1 , d2 ⟩ dcomplete


  -- contexts that only produce complete types
  _gcomplete : tctx → Set
  Γ gcomplete = (x : Nat) (τ : htyp) → (x , τ) ∈ Γ → τ tcomplete

  -- those internal expressions where every cast is the identity cast and
  -- there are no failed casts
  data cast-id : ihexp → Set where
    CIConst  : cast-id c
    CIVar    : ∀{x} → cast-id (X x)
    CILam    : ∀{x τ d} → cast-id d → cast-id (·λ x [ τ ] d)
    CIHole   : ∀{u} → cast-id (⦇⦈⟨ u ⟩)
    CINEHole : ∀{d u} → cast-id d → cast-id (⦇⌜ d ⌟⦈⟨ u ⟩)
    CIAp     : ∀{d1 d2} → cast-id d1 → cast-id d2 → cast-id (d1 ∘ d2)
    CICast   : ∀{d τ} → cast-id d → cast-id (d ⟨ τ ⇒ τ ⟩)
    CIFst    : ∀{d} → cast-id d → cast-id (fst d)
    CISnd    : ∀{d} → cast-id d → cast-id (snd d)
    CIPair   : ∀{d1 d2} → cast-id d1 → cast-id d2 → cast-id ⟨ d1 , d2 ⟩

  -- expansion
  mutual
    -- synthesis
    data _⊢_⇒_~>_⊣_ : (Γ : tctx) (e : hexp) (τ : htyp) (d : ihexp) (Δ : hctx) → Set where
      ESConst : ∀{Γ} → Γ ⊢ c ⇒ b ~> c ⊣ ∅
      ESVar   : ∀{Γ x τ} → (x , τ) ∈ Γ →
                         Γ ⊢ X x ⇒ τ ~> X x ⊣ ∅
      ESLam   : ∀{Γ x τ1 τ2 e d Δ } →
                     (x # Γ) →
                     (Γ ,, (x , τ1)) ⊢ e ⇒ τ2 ~> d ⊣ Δ →
                      Γ ⊢ ·λ x [ τ1 ] e ⇒ (τ1 ==> τ2) ~> ·λ x [ τ1 ] d ⊣ Δ
      ESAp : ∀{Γ e1 τ τ1 τ1' τ2 τ2' d1 Δ1 e2 d2 Δ2 } →
              holes-disjoint e1 e2 →
              Δ1 ## Δ2 →
              Γ ⊢ e1 => τ1 →
              τ1 ▸arr τ2 ==> τ →
              Γ ⊢ e1 ⇐ (τ2 ==> τ) ~> d1 :: τ1' ⊣ Δ1 →
              Γ ⊢ e2 ⇐ τ2 ~> d2 :: τ2' ⊣ Δ2 →
              Γ ⊢ e1 ∘ e2 ⇒ τ ~> (d1 ⟨ τ1' ⇒ τ2 ==> τ ⟩) ∘ (d2 ⟨ τ2' ⇒ τ2 ⟩) ⊣ (Δ1 ∪ Δ2)
      ESEHole : ∀{ Γ u } →
                Γ ⊢ ⦇⦈[ u ] ⇒ ⦇⦈ ~> ⦇⦈⟨ u , Id Γ ⟩ ⊣  ■ (u :: ⦇⦈ [ Γ ])
      ESNEHole : ∀{ Γ e τ d u Δ } →
                 Δ ## (■ (u , Γ , ⦇⦈)) →
                 Γ ⊢ e ⇒ τ ~> d ⊣ Δ →
                 Γ ⊢ ⦇⌜ e ⌟⦈[ u ] ⇒ ⦇⦈ ~> ⦇⌜ d ⌟⦈⟨ u , Id Γ  ⟩ ⊣ (Δ ,, u :: ⦇⦈ [ Γ ])
      ESAsc : ∀ {Γ e τ d τ' Δ} →
                 Γ ⊢ e ⇐ τ ~> d :: τ' ⊣ Δ →
                 Γ ⊢ (e ·: τ) ⇒ τ ~> d ⟨ τ' ⇒ τ ⟩ ⊣ Δ
      ESFst  : ∀{Γ e τ τ' d τ1 τ2 Δ} →
                 Γ ⊢ e => τ →
                 τ ▸prod τ1 ⊗ τ2 →
                 Γ ⊢ e ⇐ τ1 ⊗ τ2 ~> d :: τ' ⊣ Δ →
                 Γ ⊢ fst e ⇒ τ1 ~> fst (d ⟨ τ' ⇒ τ1 ⊗ τ2 ⟩) ⊣ Δ
      ESSnd  : ∀{Γ e τ τ' d τ1 τ2 Δ} →
                 Γ ⊢ e => τ →
                 τ ▸prod τ1 ⊗ τ2 →
                 Γ ⊢ e ⇐ τ1 ⊗ τ2 ~> d :: τ' ⊣ Δ →
                 Γ ⊢ snd e ⇒ τ2 ~> snd (d ⟨ τ' ⇒ τ1 ⊗ τ2 ⟩) ⊣ Δ
      ESPair : ∀{Γ e1 τ1 d1 Δ1 e2 τ2 d2 Δ2} →
                 holes-disjoint e1 e2 →
                 Δ1 ## Δ2 →
                 Γ ⊢ e1 ⇒ τ1 ~> d1 ⊣ Δ1 →
                 Γ ⊢ e2 ⇒ τ2 ~> d2 ⊣ Δ2 →
                 Γ ⊢ ⟨ e1 , e2 ⟩ ⇒ τ1 ⊗ τ2 ~> ⟨ d1 , d2 ⟩ ⊣ (Δ1 ∪ Δ2)

    -- analysis
    data _⊢_⇐_~>_::_⊣_ : (Γ : tctx) (e : hexp) (τ : htyp) (d : ihexp) (τ' : htyp) (Δ : hctx) → Set where
      EALam : ∀{Γ x τ τ1 τ2 e d τ2' Δ } →
              (x # Γ) →
              τ ▸arr τ1 ==> τ2 →
              (Γ ,, (x , τ1)) ⊢ e ⇐ τ2 ~> d :: τ2' ⊣ Δ →
              Γ ⊢ ·λ x e ⇐ τ ~> ·λ x [ τ1 ] d :: τ1 ==> τ2' ⊣ Δ
      EASubsume : ∀{e Γ τ' d Δ τ} →
                  ((u : Nat) → e ≠ ⦇⦈[ u ]) →
                  ((e' : hexp) (u : Nat) → e ≠ ⦇⌜ e' ⌟⦈[ u ]) →
                  Γ ⊢ e ⇒ τ' ~> d ⊣ Δ →
                  τ ~ τ' →
                  Γ ⊢ e ⇐ τ ~> d :: τ' ⊣ Δ
      EAEHole : ∀{ Γ u τ  } →
                Γ ⊢ ⦇⦈[ u ] ⇐ τ ~> ⦇⦈⟨ u , Id Γ  ⟩ :: τ ⊣ ■ (u :: τ [ Γ ])
      EANEHole : ∀{ Γ e u τ d τ' Δ  } →
                 Δ ## (■ (u , Γ , τ)) →
                 Γ ⊢ e ⇒ τ' ~> d ⊣ Δ →
                 Γ ⊢ ⦇⌜ e ⌟⦈[ u ] ⇐ τ ~> ⦇⌜ d ⌟⦈⟨ u , Id Γ  ⟩ :: τ ⊣ (Δ ,, u :: τ [ Γ ])

  -- ground types
  data _ground : (τ : htyp) → Set where
    GBase : b ground
    GHole : ⦇⦈ ==> ⦇⦈ ground
    GProd : ⦇⦈ ⊗ ⦇⦈ ground

  mutual
    -- substitution typing
    data _,_⊢_:s:_ : hctx → tctx → env → tctx → Set where
      STAId : ∀{Γ Γ' Δ} →
                  ((x : Nat) (τ : htyp) → (x , τ) ∈ Γ' → (x , τ) ∈ Γ) →
                  Δ , Γ ⊢ Id Γ' :s: Γ'
      STASubst : ∀{Γ Δ σ y Γ' d τ } →
               Δ , Γ ,, (y , τ) ⊢ σ :s: Γ' →
               Δ , Γ ⊢ d :: τ →
               Δ , Γ ⊢ Subst d y σ :s: Γ'

    -- type assignment
    data _,_⊢_::_ : (Δ : hctx) (Γ : tctx) (d : ihexp) (τ : htyp) → Set where
      TAConst : ∀{Δ Γ} → Δ , Γ ⊢ c :: b
      TAVar : ∀{Δ Γ x τ} → (x , τ) ∈ Γ → Δ , Γ ⊢ X x :: τ
      TALam : ∀{ Δ Γ x τ1 d τ2} →
              x # Γ →
              Δ , (Γ ,, (x , τ1)) ⊢ d :: τ2 →
              Δ , Γ ⊢ ·λ x [ τ1 ] d :: (τ1 ==> τ2)
      TAAp : ∀{ Δ Γ d1 d2 τ1 τ} →
             Δ , Γ ⊢ d1 :: τ1 ==> τ →
             Δ , Γ ⊢ d2 :: τ1 →
             Δ , Γ ⊢ d1 ∘ d2 :: τ
      TAEHole : ∀{ Δ Γ σ u Γ' τ} →
                (u , (Γ' , τ)) ∈ Δ →
                Δ , Γ ⊢ σ :s: Γ' →
                Δ , Γ ⊢ ⦇⦈⟨ u , σ ⟩ :: τ
      TANEHole : ∀ { Δ Γ d τ' Γ' u σ τ } →
                 (u , (Γ' , τ)) ∈ Δ →
                 Δ , Γ ⊢ d :: τ' →
                 Δ , Γ ⊢ σ :s: Γ' →
                 Δ , Γ ⊢ ⦇⌜ d ⌟⦈⟨ u , σ ⟩ :: τ
      TACast : ∀{ Δ Γ d τ1 τ2} →
             Δ , Γ ⊢ d :: τ1 →
             τ1 ~ τ2 →
             Δ , Γ ⊢ d ⟨ τ1 ⇒ τ2 ⟩ :: τ2
      TAFailedCast : ∀{Δ Γ d τ1 τ2} →
             Δ , Γ ⊢ d :: τ1 →
             τ1 ground →
             τ2 ground →
             τ1 ≠ τ2 →
             Δ , Γ ⊢ d ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩ :: τ2
      TAFst : ∀{Δ Γ d τ1 τ2} →
             Δ , Γ ⊢ d :: τ1 ⊗ τ2 →
             Δ , Γ ⊢ fst d :: τ1
      TASnd : ∀{Δ Γ d τ1 τ2} →
             Δ , Γ ⊢ d :: τ1 ⊗ τ2 →
             Δ , Γ ⊢ snd d :: τ2
      TAPair : ∀{Δ Γ d1 d2 τ1 τ2} →
             Δ , Γ ⊢ d1 :: τ1 →
             Δ , Γ ⊢ d2 :: τ2 →
             Δ , Γ ⊢ ⟨ d1 , d2 ⟩ :: τ1 ⊗ τ2

  -- substitution
  [_/_]_ : ihexp → Nat → ihexp → ihexp
  [ d / y ] c = c
  [ d / y ] X x
    with natEQ x y
  [ d / y ] X .y | Inl refl = d
  [ d / y ] X x  | Inr neq = X x
  [ d / y ] (·λ x [ x₁ ] d')
    with natEQ x y
  [ d / y ] (·λ .y [ τ ] d') | Inl refl = ·λ y [ τ ] d'
  [ d / y ] (·λ x [ τ ] d')  | Inr x₁ = ·λ x [ τ ] ( [ d / y ] d')
  [ d / y ] ⦇⦈⟨ u , σ ⟩ = ⦇⦈⟨ u , Subst d y σ ⟩
  [ d / y ] ⦇⌜ d' ⌟⦈⟨ u , σ  ⟩ =  ⦇⌜ [ d / y ] d' ⌟⦈⟨ u , Subst d y σ ⟩
  [ d / y ] (d1 ∘ d2) = ([ d / y ] d1) ∘ ([ d / y ] d2)
  [ d / y ] (d' ⟨ τ1 ⇒ τ2 ⟩ ) = ([ d / y ] d') ⟨ τ1 ⇒ τ2 ⟩
  [ d / y ] (d' ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩ ) = ([ d / y ] d') ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩
  [ d / y ] ⟨ d1 , d2 ⟩ = ⟨ [ d / y ] d1 , [ d / y ] d2 ⟩
  [ d / y ] (fst d') = fst ([ d / y ] d')
  [ d / y ] (snd d') = snd ([ d / y ] d')

  -- applying an environment to an expression
  apply-env : env → ihexp → ihexp
  apply-env (Id Γ) d = d
  apply-env (Subst d y σ) d' = [ d / y ] ( apply-env σ d')

  -- values
  data _val : (d : ihexp) → Set where
    VConst : c val
    VLam   : ∀{x τ d} → (·λ x [ τ ] d) val
    VPair  : ∀{d1 d2} → d1 val → d2 val → ⟨ d1 , d2 ⟩ val

  -- boxed values
  data _boxedval : (d : ihexp) → Set where
    BVVal : ∀{d} → d val → d boxedval
    BVPair : ∀{d1 d2} → d1 boxedval → d2 boxedval → ⟨ d1 , d2 ⟩ boxedval
    BVArrCast : ∀{ d τ1 τ2 τ3 τ4 } →
                τ1 ==> τ2 ≠ τ3 ==> τ4 →
                d boxedval →
                d ⟨ (τ1 ==> τ2) ⇒ (τ3 ==> τ4) ⟩ boxedval
    BVProdCast : ∀{ d τ1 τ2 τ3 τ4 } →
                τ1 ⊗ τ2 ≠ τ3 ⊗ τ4 →
                d boxedval →
                d ⟨ (τ1 ⊗ τ2) ⇒ (τ3 ⊗ τ4) ⟩ boxedval
    BVHoleCast : ∀{ τ d } → τ ground → d boxedval → d ⟨ τ ⇒ ⦇⦈ ⟩ boxedval

  mutual
    -- indeterminate forms
    data _indet : (d : ihexp) → Set where
      IEHole : ∀{u σ} → ⦇⦈⟨ u , σ ⟩ indet
      INEHole : ∀{d u σ} → d final → ⦇⌜ d ⌟⦈⟨ u , σ ⟩ indet
      IAp : ∀{d1 d2} → ((τ1 τ2 τ3 τ4 : htyp) (d1' : ihexp) →
                       d1 ≠ (d1' ⟨(τ1 ==> τ2) ⇒ (τ3 ==> τ4)⟩)) →
                       d1 indet →
                       d2 final →
                       (d1 ∘ d2) indet
      IFst   : ∀{d} →
               d indet →
               (∀{d1 d2} → d ≠ ⟨ d1 , d2 ⟩) →
               (∀{d' τ1 τ2 τ3 τ4} → d ≠ (d' ⟨ τ1 ⊗ τ2 ⇒ τ3 ⊗ τ4 ⟩)) →
               (fst d) indet
      ISnd   : ∀{d} →
               d indet →
               (∀{d1 d2} → d ≠ ⟨ d1 , d2 ⟩) →
               (∀{d' τ1 τ2 τ3 τ4} → d ≠ (d' ⟨ τ1 ⊗ τ2 ⇒ τ3 ⊗ τ4 ⟩)) →
               (snd d) indet
      IPair1 : ∀{d1 d2} →
               d1 indet →
               d2 final →
               ⟨ d1 , d2 ⟩ indet
      IPair2 : ∀{d1 d2} →
               d1 final →
               d2 indet →
               ⟨ d1 , d2 ⟩ indet
      ICastArr : ∀{d τ1 τ2 τ3 τ4} →
                 τ1 ==> τ2 ≠ τ3 ==> τ4 →
                 d indet →
                 d ⟨ (τ1 ==> τ2) ⇒ (τ3 ==> τ4) ⟩ indet
      ICastProd : ∀{d τ1 τ2 τ3 τ4} →
                 τ1 ⊗ τ2 ≠ τ3 ⊗ τ4 →
                 d indet →
                 d ⟨ (τ1 ⊗ τ2) ⇒ (τ3 ⊗ τ4) ⟩ indet
      ICastGroundHole : ∀{ τ d } →
                        τ ground →
                        d indet →
                        d ⟨ τ ⇒  ⦇⦈ ⟩ indet
      ICastHoleGround : ∀ { d τ } →
                        ((d' : ihexp) (τ' : htyp) → d ≠ (d' ⟨ τ' ⇒ ⦇⦈ ⟩)) →
                        d indet →
                        τ ground →
                        d ⟨ ⦇⦈ ⇒ τ ⟩ indet
      IFailedCast : ∀{ d τ1 τ2 } →
                    d final →
                    τ1 ground →
                    τ2 ground →
                    τ1 ≠ τ2 →
                    d ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩ indet

    -- final expressions
    data _final : (d : ihexp) → Set where
      FBoxedVal : ∀{d} → d boxedval → d final
      FIndet    : ∀{d} → d indet    → d final


  -- contextual dynamics

  -- evaluation contexts
  data ectx : Set where
    ⊙ : ectx
    _∘₁_ : ectx → ihexp → ectx
    _∘₂_ : ihexp → ectx → ectx
    ⦇⌜_⌟⦈⟨_⟩ : ectx → (Nat × env ) → ectx
    fst·_ : ectx → ectx
    snd·_ : ectx → ectx
    ⟨_,_⟩₁ : ectx → ihexp → ectx
    ⟨_,_⟩₂ : ihexp → ectx → ectx
    _⟨_⇒_⟩ : ectx → htyp → htyp → ectx
    _⟨_⇒⦇⦈⇏_⟩ : ectx → htyp → htyp → ectx

  -- note: this judgement is redundant: in the absence of the premises in
  -- the red brackets, all syntactically well formed ectxs are valid. with
  -- finality premises, that's not true, and that would propagate through
  -- additions to the calculus. so we leave it here for clarity but note
  -- that, as written, in any use case its either trival to prove or
  -- provides no additional information

   --ε is an evaluation context
  data _evalctx : (ε : ectx) → Set where
    ECDot : ⊙ evalctx
    ECAp1 : ∀{d ε} →
            ε evalctx →
            (ε ∘₁ d) evalctx
    ECAp2 : ∀{d ε} →
            -- d final → -- red brackets
            ε evalctx →
            (d ∘₂ ε) evalctx
    ECNEHole : ∀{ε u σ} →
               ε evalctx →
               ⦇⌜ ε ⌟⦈⟨ u , σ ⟩ evalctx
    ECFst   : ∀{ε} →
              (fst· ε) evalctx
    ECSnd   : ∀{ε} →
              (snd· ε) evalctx
    ECPair1 : ∀{d ε} →
              ε evalctx →
              ⟨ ε , d ⟩₁ evalctx
    ECPair2 : ∀{d ε} →
              -- d final → -- red brackets
              ε evalctx →
              ⟨ d , ε ⟩₂ evalctx
    ECCast : ∀{ ε τ1 τ2} →
             ε evalctx →
             (ε ⟨ τ1 ⇒ τ2 ⟩) evalctx
    ECFailedCast : ∀{ ε τ1 τ2 } →
                   ε evalctx →
                   ε ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩ evalctx

  -- d is the result of filling the hole in ε with d'
  data _==_⟦_⟧ : (d : ihexp) (ε : ectx) (d' : ihexp) → Set where
    FHOuter : ∀{d} → d == ⊙ ⟦ d ⟧
    FHAp1 : ∀{d1 d1' d2 ε} →
           d1 == ε ⟦ d1' ⟧ →
           (d1 ∘ d2) == (ε ∘₁ d2) ⟦ d1' ⟧
    FHAp2 : ∀{d1 d2 d2' ε} →
           -- d1 final → -- red brackets
           d2 == ε ⟦ d2' ⟧ →
           (d1 ∘ d2) == (d1 ∘₂ ε) ⟦ d2' ⟧
    FHNEHole : ∀{ d d' ε u σ} →
              d == ε ⟦ d' ⟧ →
              ⦇⌜ d ⌟⦈⟨ (u , σ ) ⟩ ==  ⦇⌜ ε ⌟⦈⟨ (u , σ ) ⟩ ⟦ d' ⟧
    FHFst   : ∀{d d' ε} →
              d == ε ⟦ d' ⟧ →
              fst d == (fst· ε) ⟦ d' ⟧
    FHSnd   : ∀{d d' ε} →
              d == ε ⟦ d' ⟧ →
              snd d == (snd· ε) ⟦ d' ⟧
    FHPair1 : ∀{d1 d1' d2 ε} →
              d1 == ε ⟦ d1' ⟧ →
              ⟨ d1 , d2 ⟩ == ⟨ ε , d2 ⟩₁ ⟦ d1' ⟧
    FHPair2 : ∀{d1 d2 d2' ε} →
              d2 == ε ⟦ d2' ⟧ →
              ⟨ d1 , d2 ⟩ == ⟨ d1 , ε ⟩₂ ⟦ d2' ⟧
    FHCast : ∀{ d d' ε τ1 τ2 } →
            d == ε ⟦ d' ⟧ →
            d ⟨ τ1 ⇒ τ2 ⟩ == ε ⟨ τ1 ⇒ τ2 ⟩ ⟦ d' ⟧
    FHFailedCast : ∀{ d d' ε τ1 τ2} →
            d == ε ⟦ d' ⟧ →
            (d ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩) == (ε ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩) ⟦ d' ⟧

  -- matched ground types
  data _▸gnd_ : htyp → htyp → Set where
    MGArr : ∀{τ1 τ2} →
            (τ1 ==> τ2) ≠ (⦇⦈ ==> ⦇⦈) →
            (τ1 ==> τ2) ▸gnd (⦇⦈ ==> ⦇⦈)
    MGProd : ∀{τ1 τ2} →
            (τ1 ⊗ τ2) ≠ (⦇⦈ ⊗ ⦇⦈) →
            (τ1 ⊗ τ2) ▸gnd (⦇⦈ ⊗ ⦇⦈)

  -- instruction transition judgement
  data _→>_ : (d d' : ihexp) → Set where
    ITLam : ∀{ x τ d1 d2 } →
            -- d2 final → -- red brackets
            ((·λ x [ τ ] d1) ∘ d2) →> ([ d2 / x ] d1)
    ITFst : ∀{d1 d2} →
            -- d1 final → -- red brackets
            -- d2 final → -- red brackets
            fst ⟨ d1 , d2 ⟩ →> d1
    ITSnd : ∀{d1 d2} →
            -- d1 final → -- red brackets
            -- d2 final → -- red brackets
            snd ⟨ d1 , d2 ⟩ →> d2
    ITCastID : ∀{d τ } →
               -- d final → -- red brackets
               (d ⟨ τ ⇒ τ ⟩) →> d
    ITCastSucceed : ∀{d τ } →
                    -- d final → -- red brackets
                    τ ground →
                    (d ⟨ τ ⇒ ⦇⦈ ⇒ τ ⟩) →> d
    ITCastFail : ∀{ d τ1 τ2} →
                 -- d final → -- red brackets
                 τ1 ground →
                 τ2 ground →
                 τ1 ≠ τ2 →
                 (d ⟨ τ1 ⇒ ⦇⦈ ⇒ τ2 ⟩) →> (d ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩)
    ITApCast : ∀{d1 d2 τ1 τ2 τ1' τ2' } →
               -- d1 final → -- red brackets
               -- d2 final → -- red brackets
               ((d1 ⟨ (τ1 ==> τ2) ⇒ (τ1' ==> τ2')⟩) ∘ d2) →> ((d1 ∘ (d2 ⟨ τ1' ⇒ τ1 ⟩)) ⟨ τ2 ⇒ τ2' ⟩)
    ITFstCast : ∀{d τ1 τ2 τ1' τ2' } →
               -- d final → -- red brackets
               fst (d ⟨ τ1 ⊗ τ2 ⇒ τ1' ⊗ τ2' ⟩) →> ((fst d) ⟨ τ1 ⇒ τ1' ⟩)
    ITSndCast : ∀{d τ1 τ2 τ1' τ2' } →
               -- d final → -- red brackets
               snd (d ⟨ τ1 ⊗ τ2 ⇒ τ1' ⊗ τ2' ⟩) →> ((snd d) ⟨ τ2 ⇒ τ2' ⟩)
    ITGround : ∀{ d τ τ'} →
               -- d final → -- red brackets
               τ ▸gnd τ' →
               (d ⟨ τ ⇒ ⦇⦈ ⟩) →> (d ⟨ τ ⇒ τ' ⇒ ⦇⦈ ⟩)
    ITExpand : ∀{d τ τ' } →
               -- d final → -- red brackets
               τ ▸gnd τ' →
               (d ⟨ ⦇⦈ ⇒ τ ⟩) →> (d ⟨ ⦇⦈ ⇒ τ' ⇒ τ ⟩)

  -- single step (in contextual evaluation sense)
  data _↦_ : (d d' : ihexp) → Set where
    Step : ∀{ d d0 d' d0' ε} →
           d == ε ⟦ d0 ⟧ →
           d0 →> d0' →
           d' == ε ⟦ d0' ⟧ →
           d ↦ d'

  -- reflexive transitive closure of single steps into multi steps
  data _↦*_ : (d d' : ihexp) → Set where
    MSRefl : ∀{d} → d ↦* d
    MSStep : ∀{d d' d''} →
                 d ↦ d' →
                 d' ↦* d'' →
                 d  ↦* d''

  -- freshness
  mutual
    -- ... with respect to a hole context
    data envfresh : Nat → env → Set where
      EFId : ∀{x Γ} → x # Γ → envfresh x (Id Γ)
      EFSubst : ∀{x d σ y} → fresh x d
                           → envfresh x σ
                           → x ≠ y
                           → envfresh x (Subst d y σ)

    -- ... for inernal expressions
    data fresh : Nat → ihexp → Set where
      FConst : ∀{x} → fresh x c
      FVar   : ∀{x y} → x ≠ y → fresh x (X y)
      FLam   : ∀{x y τ d} → x ≠ y → fresh x d → fresh x (·λ y [ τ ] d)
      FHole  : ∀{x u σ} → envfresh x σ → fresh x (⦇⦈⟨ u , σ ⟩)
      FNEHole : ∀{x d u σ} → envfresh x σ → fresh x d → fresh x (⦇⌜ d ⌟⦈⟨ u , σ ⟩)
      FAp     : ∀{x d1 d2} → fresh x d1 → fresh x d2 → fresh x (d1 ∘ d2)
      FCast   : ∀{x d τ1 τ2} → fresh x d → fresh x (d ⟨ τ1 ⇒ τ2 ⟩)
      FFailedCast : ∀{x d τ1 τ2} → fresh x d → fresh x (d ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩)
      FFst  : ∀{x d} → fresh x d → fresh x (fst d)
      FSnd  : ∀{x d} → fresh x d → fresh x (snd d)
      FPair : ∀{x d1 d2} → fresh x d1 → fresh x d2 → fresh x ⟨ d1 , d2 ⟩

  -- ... for external expressions
  data freshh : Nat → hexp → Set where
    FRHConst : ∀{x} → freshh x c
    FRHAsc   : ∀{x e τ} → freshh x e → freshh x (e ·: τ)
    FRHVar   : ∀{x y} → x ≠ y → freshh x (X y)
    FRHLam1  : ∀{x y e} → x ≠ y → freshh x e → freshh x (·λ y e)
    FRHLam2  : ∀{x τ e y} → x ≠ y → freshh x e → freshh x (·λ y [ τ ] e)
    FRHEHole : ∀{x u} → freshh x (⦇⦈[ u ])
    FRHNEHole : ∀{x u e} → freshh x e → freshh x (⦇⌜ e ⌟⦈[ u ])
    FRHAp : ∀{x e1 e2} → freshh x e1 → freshh x e2 → freshh x (e1 ∘ e2)
    FRHFst  : ∀{x e} → freshh x e → freshh x (fst e)
    FRHSnd  : ∀{x e} → freshh x e → freshh x (snd e)
    FRHPair : ∀{x e1 e2} → freshh x e1 → freshh x e2 → freshh x ⟨ e1 , e2 ⟩

  -- with respect to all bindings in a context
  freshΓ : {A : Set} → (Γ : A ctx) → (e : hexp) → Set
  freshΓ {A} Γ e = (x : Nat) → dom Γ x → freshh x e

  -- x is not used in a binding site in d
  mutual
    data unbound-in-σ : Nat → env → Set where
      UBσId : ∀{x Γ} → unbound-in-σ x (Id Γ)
      UBσSubst : ∀{x d y σ} → unbound-in x d
                            → unbound-in-σ x σ
                            → x ≠ y
                            → unbound-in-σ x (Subst d y σ)

    data unbound-in : (x : Nat) (d : ihexp) → Set where
      UBConst : ∀{x} → unbound-in x c
      UBVar : ∀{x y} → unbound-in x (X y)
      UBLam2 : ∀{x d y τ} → x ≠ y
                           → unbound-in x d
                           → unbound-in x (·λ_[_]_ y τ d)
      UBHole : ∀{x u σ} → unbound-in-σ x σ
                         → unbound-in x (⦇⦈⟨ u , σ ⟩)
      UBNEHole : ∀{x u σ d }
                  → unbound-in-σ x σ
                  → unbound-in x d
                  → unbound-in x (⦇⌜ d ⌟⦈⟨ u , σ ⟩)
      UBAp : ∀{ x d1 d2 } →
            unbound-in x d1 →
            unbound-in x d2 →
            unbound-in x (d1 ∘ d2)
      UBCast : ∀{x d τ1 τ2} → unbound-in x d → unbound-in x (d ⟨ τ1 ⇒ τ2 ⟩)
      UBFailedCast : ∀{x d τ1 τ2} → unbound-in x d → unbound-in x (d ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩)
      UBFst  : ∀{x d} → unbound-in x d → unbound-in x (fst d)
      UBSnd  : ∀{x d} → unbound-in x d → unbound-in x (snd d)
      UBPair : ∀{x d1 d2} → unbound-in x d1 → unbound-in x d2 → unbound-in x ⟨ d1 , d2 ⟩

  mutual
    data binders-disjoint-σ : env → ihexp → Set where
      BDσId : ∀{Γ d} → binders-disjoint-σ (Id Γ) d
      BDσSubst : ∀{d1 d2 y σ} → binders-disjoint d1 d2
                              → binders-disjoint-σ σ d2
                              → binders-disjoint-σ (Subst d1 y σ) d2

    -- two terms that do not share any binders
    data binders-disjoint : (d1 : ihexp) → (d2 : ihexp) → Set where
      BDConst : ∀{d} → binders-disjoint c d
      BDVar : ∀{x d} → binders-disjoint (X x) d
      BDLam : ∀{x τ d1 d2} → binders-disjoint d1 d2
                            → unbound-in x d2
                            → binders-disjoint (·λ_[_]_ x τ d1) d2
      BDHole : ∀{u σ d2} → binders-disjoint-σ σ d2
                         → binders-disjoint (⦇⦈⟨ u , σ ⟩) d2
      BDNEHole : ∀{u σ d1 d2} → binders-disjoint-σ σ d2
                              → binders-disjoint d1 d2
                              → binders-disjoint (⦇⌜ d1 ⌟⦈⟨ u , σ ⟩) d2
      BDAp :  ∀{d1 d2 d3} → binders-disjoint d1 d3
                          → binders-disjoint d2 d3
                          → binders-disjoint (d1 ∘ d2) d3
      BDCast : ∀{d1 d2 τ1 τ2} → binders-disjoint d1 d2 → binders-disjoint (d1 ⟨ τ1 ⇒ τ2 ⟩) d2
      BDFailedCast : ∀{d1 d2 τ1 τ2} → binders-disjoint d1 d2 → binders-disjoint (d1 ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩) d2
      BDFst  : ∀{d1 d2} → binders-disjoint d1 d2 → binders-disjoint (fst d1) d2
      BDSnd  : ∀{d1 d2} → binders-disjoint d1 d2 → binders-disjoint (snd d1) d2
      BDPair : ∀{d1 d2 d3} →
               binders-disjoint d1 d3 →
               binders-disjoint d2 d3 →
               binders-disjoint ⟨ d1 , d2 ⟩ d3

  mutual
  -- each term has to be binders unique, and they have to be pairwise
  -- disjoint with the collection of bound vars
    data binders-unique-σ : env → Set where
      BUσId : ∀{Γ} → binders-unique-σ (Id Γ)
      BUσSubst : ∀{d y σ} → binders-unique d
                          → binders-unique-σ σ
                          → binders-disjoint-σ σ d
                          → binders-unique-σ (Subst d y σ)

    -- all the variable names in the term are unique
    data binders-unique : ihexp → Set where
      BUHole : binders-unique c
      BUVar : ∀{x} → binders-unique (X x)
      BULam : {x : Nat} {τ : htyp} {d : ihexp} → binders-unique d
                                                → unbound-in x d
                                                → binders-unique (·λ_[_]_ x τ d)
      BUEHole : ∀{u σ} → binders-unique-σ σ
                        → binders-unique (⦇⦈⟨ u , σ ⟩)
      BUNEHole : ∀{u σ d} → binders-unique d
                           → binders-unique-σ σ
                           → binders-unique (⦇⌜ d ⌟⦈⟨ u , σ ⟩)
      BUAp : ∀{d1 d2} → binders-unique d1
                       → binders-unique d2
                       → binders-disjoint d1 d2
                       → binders-unique (d1 ∘ d2)
      BUCast : ∀{d τ1 τ2} → binders-unique d
                           → binders-unique (d ⟨ τ1 ⇒ τ2 ⟩)
      BUFailedCast : ∀{d τ1 τ2} → binders-unique d
                                 → binders-unique (d ⟨ τ1 ⇒⦇⦈⇏ τ2 ⟩)
      BUFst  : ∀{d} →
               binders-unique d →
               binders-unique (fst d)
      BUSnd  : ∀{d} →
               binders-unique d →
               binders-unique (snd d)
      BUPair : ∀{d1 d2} →
               binders-unique d1 →
               binders-unique d2 →
               binders-disjoint d1 d2 →
               binders-unique ⟨ d1 , d2 ⟩

  _⇓_ : ihexp → ihexp → Set
  d1 ⇓ d2 = (d1 ↦* d2 × d2 final)

  -- this is the decoding function, so half the iso. this won't work long term
  postulate
    _↑_ : ihexp → hexp → Set
    _↓_ : hexp → ihexp → Set -- not used
    iso : Set
    Exp : htyp

-- naming conventions:
--
-- pal names are ρ
-- pexps are p
-- paldefs are π

  -- palette expansion -- todo, should this be called elaboration?
  mutual
    data _,_⊢_~~>_⇒_ : (Φ : paldef ctx) →
                       (Γ : tctx) →
                       (P : pexp) →
                       (e : hexp) →
                       (τ : htyp) →
                       Set
      where
        SPEConst : ∀{Φ Γ} → Φ , Γ ⊢ c ~~> c ⇒ b
        SPEAsc   : ∀{Φ Γ p e τ} →
                           Φ , Γ ⊢ p ~~> e ⇐ τ →
                           Φ , Γ ⊢ (p ·: τ) ~~> e ·: τ ⇒ τ
        SPEVar   : ∀{Φ Γ x τ} →
                           (x , τ) ∈ Γ →
                           Φ , Γ ⊢ (X x) ~~> (X x) ⇒ τ
        SPELam   : ∀{Φ Γ x e τ1 τ2} {p : pexp} →
                           x # Γ →
                           Φ , Γ ,, (x , τ1) ⊢ p ~~> e ⇒ τ2 →
                           Φ , Γ ⊢ (·λ_[_]_ x τ1 p) ~~> (·λ x [ τ1 ] e) ⇒ (τ1 ==> τ2)
        SPEAp    : ∀{Φ Γ p1 p2 τ1 τ2 τ e1 e2} →
                           Φ , Γ ⊢ p1 ~~> e1 ⇒ τ1 →
                           τ1 ▸arr τ2 ==> τ →
                           Φ , Γ ⊢ p2 ~~> e2 ⇐ τ2 →
                           holes-disjoint e1 e2 →
                           Φ , Γ ⊢ p1 ∘ p2 ~~> e1 ∘ e2 ⇒ τ
        SPEHole  : ∀{Φ Γ u} → Φ , Γ ⊢ ⦇⦈[ u ] ~~> ⦇⦈[ u ] ⇒ ⦇⦈
        SPNEHole : ∀{Φ Γ p e τ u} →
                           hole-name-new e u →
                           Φ , Γ ⊢ p ~~> e ⇒ τ →
                           Φ , Γ ⊢ ⦇⌜ p ⌟⦈[ u ] ~~> ⦇⌜ e ⌟⦈[ u ] ⇒ ⦇⦈
        SPELetPal : ∀{Γ Φ π ρ p e τ} →
                           ∅ , ∅ ⊢ paldef.expand π :: ((paldef.model-type π) ==> Exp) →
                           (Φ ,, (ρ , π)) , Γ ⊢ p ~~> e ⇒ τ →
                           Φ , Γ ⊢ let-pal ρ be π ·in p ~~> e ⇒ τ
        SPEApPal  : ∀{Φ Γ ρ dm π denc eexpanded τsplice psplice esplice} →
                         holes-disjoint eexpanded esplice →
                         freshΓ Γ eexpanded →
                         (ρ , π) ∈ Φ  →
                         ∅ , ∅ ⊢ dm :: (paldef.model-type π) →
                         ((paldef.expand π) ∘ dm) ⇓ denc →
                         denc ↑ eexpanded →
                         Φ , Γ ⊢ psplice ~~> esplice ⇐ τsplice →
                         ∅ ⊢ eexpanded <= τsplice ==> (paldef.expansion-type π) →
                         Φ , Γ ⊢ ap-pal ρ dm (τsplice , psplice) ~~> ((eexpanded ·: τsplice ==> paldef.expansion-type π) ∘ esplice) ⇒ paldef.expansion-type π

    data _,_⊢_~~>_⇐_ : (Φ : paldef ctx) →
                       (Γ : tctx) →
                       (P : pexp) →
                       (e : hexp) →
                       (τ : htyp) →
                       Set
      where
        APELam     : ∀{Φ Γ x e τ τ1 τ2} {p : pexp} →
                           x # Γ →
                           τ ▸arr τ1 ==> τ2 →
                           Φ , Γ ,, (x , τ1) ⊢ p ~~> e ⇐ τ2 →
                           Φ , Γ ⊢ (·λ x p) ~~> (·λ x e) ⇐ τ
        APESubsume : ∀{Φ Γ p e τ τ'} →
                           Φ , Γ ⊢ p ~~> e ⇒ τ' →
                           τ ~ τ' →
                           Φ , Γ ⊢ p ~~> e ⇐ τ
        APELetPal  : ∀{Φ Γ π ρ p e τ} →
                           ∅ , ∅ ⊢ paldef.expand π :: ((paldef.model-type π) ==> Exp) →
                           (Φ ,, (ρ , π)) , Γ ⊢ p ~~> e ⇐ τ →
                           Φ , Γ ⊢ let-pal ρ be π ·in p ~~> e ⇐ τ
  -}
