(* ======================================================================
   THEORY: finite_map
   FILE:    finite_mapScript.sml
   DESCRIPTION: A theory of finite maps

   AUTHOR:  Graham Collins and Donald Syme

   ======================================================================
   There is little documentation in this file but a discussion of this
   theory is available as:

   @inproceedings{P-Collins-FMAP,
      author = {Graham Collins and Donald Syme},
      editor = {E. Thomas Schubert and Phillip J. Windley
                and James Alves-Foss},
      booktitle={Higher Order Logic Theorem Proving and its Applications}
      publisher = {Springer-Verlag},
      series = {Lecture Notes in Computer Science},
      title = {A Theory of Finite Maps},
      volume = {971},
      year = {1995},
      pages = {122--137}
   }

   Updated for HOL4 in 2002 by Michael Norrish.

   ===================================================================== *)

structure finite_mapScript =
struct

open HolKernel Parse boolLib IndDefLib numLib pred_setTheory
     sumTheory pairTheory BasicProvers SingleStep bossLib metisLib
     simpLib;

local open pred_setLib listTheory in end

val _ = new_theory "finite_map";

(*---------------------------------------------------------------------------*)
(* Special notation. fmap application is set at the same level as function   *)
(* application, meaning that                                                 *)
(*                                                                           *)
(*    * SOME (f ' x)    prints as   SOME (f ' x)                             *)
(*    * (f x) ' y       prints as   f x ' y                                  *)
(*    * (f ' x) y       prints as   f ' x y                                  *)
(*    * f ' (x y)       prints as   f ' (x y)                                *)
(*                                                                           *)
(*   I think this is clearly best.                                           *)
(*---------------------------------------------------------------------------*)

val _ = set_fixity "'" (Infixl 2000);    (* fmap application *)
val _ = set_fixity "|+"  (Infixl 600);   (* fmap update *)
val _ = set_fixity "|++" (Infixl 500);   (* iterated update *)
val _ = set_fixity "\\\\" (Infixl 600)   (* domain subtraction *)


(*---------------------------------------------------------------------------
        Definition of a finite map

    The representation is the type 'a -> ('b + one) where only a finite
    number of the 'a map to a 'b and the rest map to one.  We define a
    notion of finiteness inductively.
 --------------------------------------------------------------------------- *)

val (rules,ind,cases) =
 Hol_reln `is_fmap (\a. INR one)
       /\ (!f a b. is_fmap f ==> is_fmap (\x. if x=a then INL b else f x))`;


val rule_list as [is_fmap_empty, is_fmap_update] = CONJUNCTS rules;

val is_fmap_RULE_INDUCT_TAC = IndDefRules.RULE_INDUCT_THEN ind STRIP_ASSUME_TAC;

val strong_ind = IndDefRules.derive_strong_induction(rule_list, ind);


(*---------------------------------------------------------------------------
        Existence theorem; type definition
 ---------------------------------------------------------------------------*)

val EXISTENCE_THM = Q.prove
(`?x:'a -> 'b + one. is_fmap x`,
EXISTS_TAC (Term`\x:'a. (INR one):'b + one`)
 THEN REWRITE_TAC [is_fmap_empty]);

val fmap_TY_DEF = new_type_definition("fmap", EXISTENCE_THM);

val _ = add_infix_type
           {Prec = 50,
            ParseName = SOME "|->",
            Assoc = RIGHT,
            Name = "fmap"};

(* --------------------------------------------------------------------- *)
(* Define bijections                                                     *)
(* --------------------------------------------------------------------- *)

val fmap_ISO_DEF =
   define_new_type_bijections
       {name = "fmap_ISO_DEF",
        ABS  = "fmap_ABS",
        REP  = "fmap_REP",
        tyax = fmap_TY_DEF};

(* --------------------------------------------------------------------- *)
(* Prove that REP is one-to-one.					 *)
(* --------------------------------------------------------------------- *)

val fmap_REP_11   = prove_rep_fn_one_one fmap_ISO_DEF
val fmap_REP_onto = prove_rep_fn_onto fmap_ISO_DEF
val fmap_ABS_11   = prove_abs_fn_one_one fmap_ISO_DEF
val fmap_ABS_onto = prove_abs_fn_onto fmap_ISO_DEF;

val (fmap_ABS_REP_THM,fmap_REP_ABS_THM)  =
 let val thms = CONJUNCTS fmap_ISO_DEF
     val [t1,t2] = map (GEN_ALL o SYM o SPEC_ALL) thms
 in (t1,t2)
  end;


(*---------------------------------------------------------------------------
        CANCELLATION THEOREMS
 ---------------------------------------------------------------------------*)

val is_fmap_REP = Q.prove
(`!f:'a |-> 'b. is_fmap (fmap_REP f)`,
 REWRITE_TAC [fmap_REP_onto]
  THEN GEN_TAC THEN Q.EXISTS_TAC `f`
  THEN REWRITE_TAC [fmap_REP_11]);

val REP_ABS_empty = Q.prove
(`fmap_REP (fmap_ABS ((\a. INR one):'a -> 'b + one)) = \a. INR one`,
 REWRITE_TAC [fmap_REP_ABS_THM]
  THEN REWRITE_TAC [is_fmap_empty]);

val REP_ABS_update = Q.prove
(`!(f:'a |-> 'b) x y.
     fmap_REP (fmap_ABS (\a. if a=x then INL y else fmap_REP f a))
         =
     \a. if a=x then INL y else fmap_REP f a`,
 REPEAT GEN_TAC
   THEN REWRITE_TAC [fmap_REP_ABS_THM]
   THEN MATCH_MP_TAC is_fmap_update
   THEN REWRITE_TAC [is_fmap_REP]);

val is_fmap_REP_ABS = Q.prove
(`!f:'a -> 'b + one. is_fmap f ==> (fmap_REP (fmap_ABS f) = f)`,
 REPEAT STRIP_TAC
  THEN REWRITE_TAC [fmap_REP_ABS_THM]
  THEN ASM_REWRITE_TAC []);


(*---------------------------------------------------------------------------
        DEFINITIONS OF UPDATE, EMPTY, APPLY and DOMAIN
 ---------------------------------------------------------------------------*)

val FUPDATE_DEF = Q.new_definition
("FUPDATE_DEF",
 `FUPDATE (f:'a |-> 'b) (x,y)
    = fmap_ABS (\a. if a=x then INL y else fmap_REP f a)`);

val _ = overload_on ("|+", ``FUPDATE``);

val FEMPTY_DEF = Q.new_definition
("FEMPTY_DEF",
 `(FEMPTY:'a |-> 'b) = fmap_ABS (\a. INR one)`);

val FAPPLY_DEF = Q.new_definition
("FAPPLY_DEF",
 `FAPPLY (f:'a |-> 'b) x = OUTL (fmap_REP f x)`);

val _ = overload_on ("'", ``FAPPLY``);

val FDOM_DEF = Q.new_definition
("FDOM_DEF",
 `FDOM (f:'a |-> 'b) x = ISL (fmap_REP f x)`);

val update_rep = Term`\(f:'a->'b+one) x y. \a. if a=x then INL y else f a`;

val empty_rep = Term`(\a. INR one):'a -> 'b + one`;



(*---------------------------------------------------------------------------
      Now some theorems
 --------------------------------------------------------------------------- *)

val FAPPLY_FUPDATE = Q.store_thm ("FAPPLY_FUPDATE",
`!(f:'a |-> 'b) x y. FAPPLY (FUPDATE f (x,y)) x = y`,
 REWRITE_TAC [FUPDATE_DEF, FAPPLY_DEF]
   THEN REPEAT GEN_TAC
    THEN REWRITE_TAC [REP_ABS_update] THEN BETA_TAC
    THEN REWRITE_TAC [sumTheory.OUTL]);

val _ = export_rewrites ["FAPPLY_FUPDATE"]

val NOT_EQ_FAPPLY = Q.store_thm ("NOT_EQ_FAPPLY",
`!(f:'a|-> 'b) a x y . ~(a=x) ==> (FAPPLY (FUPDATE f (x,y)) a = FAPPLY f a)`,
REPEAT STRIP_TAC
  THEN REWRITE_TAC [FUPDATE_DEF, FAPPLY_DEF, REP_ABS_update] THEN BETA_TAC
  THEN ASM_REWRITE_TAC []);

val update_commutes_rep = (BETA_RULE o BETA_RULE) (Q.prove
(`!(f:'a -> 'b + one) a b c d.
     ~(a = c)
        ==>
 (^update_rep (^update_rep f a b) c d = ^update_rep (^update_rep f c d) a b)`,
REPEAT STRIP_TAC THEN BETA_TAC
  THEN MATCH_MP_TAC EQ_EXT
  THEN GEN_TAC
  THEN Q.ASM_CASES_TAC `x = a` THEN BETA_TAC
  THEN ASM_REWRITE_TAC []));


val FUPDATE_COMMUTES = Q.store_thm ("FUPDATE_COMMUTES",
`!(f:'a |-> 'b) a b c d.
   ~(a = c)
     ==>
  (FUPDATE (FUPDATE f (a,b)) (c,d) = FUPDATE (FUPDATE f (c,d)) (a,b))`,
REPEAT STRIP_TAC
  THEN REWRITE_TAC [FUPDATE_DEF, REP_ABS_update] THEN BETA_TAC
  THEN AP_TERM_TAC
  THEN MATCH_MP_TAC EQ_EXT
  THEN GEN_TAC
  THEN Q.ASM_CASES_TAC `x = a` THEN BETA_TAC
  THEN ASM_REWRITE_TAC []);

val update_same_rep = (BETA_RULE o BETA_RULE) (Q.prove
(`!(f:'a -> 'b+one) a b c.
   ^update_rep (^update_rep f a b) a c = ^update_rep f a c`,
BETA_TAC THEN REPEAT GEN_TAC
  THEN MATCH_MP_TAC EQ_EXT
  THEN GEN_TAC
  THEN Q.ASM_CASES_TAC `x = a` THEN BETA_TAC
  THEN ASM_REWRITE_TAC []));

val FUPDATE_EQ = Q.store_thm ("FUPDATE_EQ",
`!(f:'a |-> 'b) a b c. FUPDATE (FUPDATE f (a,b)) (a,c) = FUPDATE f (a,c)`,
REPEAT STRIP_TAC
  THEN REWRITE_TAC [FUPDATE_DEF, REP_ABS_update] THEN BETA_TAC
  THEN AP_TERM_TAC
  THEN MATCH_MP_TAC EQ_EXT
  THEN GEN_TAC
  THEN Q.ASM_CASES_TAC `x = a` THEN BETA_TAC
  THEN ASM_REWRITE_TAC []);

val _ = export_rewrites ["FUPDATE_EQ"]

val lemma1 = Q.prove
(`~((ISL :'b + one -> bool) ((INR :one -> 'b + one) one))`,
 REWRITE_TAC [sumTheory.ISL]);

val FDOM_FEMPTY = Q.store_thm ("FDOM_FEMPTY",
`FDOM (FEMPTY:'a |-> 'b) = {}`,
REWRITE_TAC [EXTENSION, NOT_IN_EMPTY] THEN
REWRITE_TAC [SPECIFICATION, FDOM_DEF, FEMPTY_DEF, REP_ABS_empty,
             sumTheory.ISL]);

val _ = export_rewrites ["FDOM_FEMPTY"]

val dom_update_rep = BETA_RULE (Q.prove
(`!f a b x. ISL(^update_rep (f:'a -> 'b+one ) a b x) = ((x=a) \/ ISL (f x))`,
REPEAT GEN_TAC THEN BETA_TAC
  THEN Q.ASM_CASES_TAC `x = a`
  THEN ASM_REWRITE_TAC [sumTheory.ISL]));

val FDOM_FUPDATE = Q.store_thm(
  "FDOM_FUPDATE",
  `!f a b. FDOM (FUPDATE (f:'a |-> 'b) (a,b)) = a INSERT FDOM f`,
  REPEAT GEN_TAC THEN
  REWRITE_TAC [EXTENSION, IN_INSERT] THEN
  REWRITE_TAC [SPECIFICATION, FDOM_DEF,FUPDATE_DEF, REP_ABS_update] THEN
  BETA_TAC THEN GEN_TAC THEN Q.ASM_CASES_TAC `x = a` THEN
  ASM_REWRITE_TAC [sumTheory.ISL]);

val _ = export_rewrites ["FDOM_FUPDATE"]

val FAPPLY_FUPDATE_THM = Q.store_thm("FAPPLY_FUPDATE_THM",
`!(f:'a |-> 'b) a b x.
   FAPPLY(FUPDATE f (a,b)) x = if x=a then b else FAPPLY f x`,
REPEAT STRIP_TAC
  THEN COND_CASES_TAC
  THEN ASM_REWRITE_TAC [FAPPLY_FUPDATE]
  THEN IMP_RES_TAC NOT_EQ_FAPPLY
  THEN ASM_REWRITE_TAC []);

val not_eq_empty_update_rep = BETA_RULE (Q.prove
(`!(f:'a -> 'b + one) a b. ~(^empty_rep = ^update_rep f a b)`,
REPEAT GEN_TAC THEN BETA_TAC
  THEN CONV_TAC (DEPTH_CONV FUN_EQ_CONV)
  THEN CONV_TAC NOT_FORALL_CONV
  THEN Q.EXISTS_TAC `a` THEN BETA_TAC
  THEN DISCH_THEN (fn th => REWRITE_TAC [REWRITE_RULE [sumTheory.ISL]
                               (REWRITE_RULE [th] lemma1)])));

val fmap_EQ_1 = Q.prove
(`!(f:'a |-> 'b) g. (f=g) ==> (FDOM f = FDOM g) /\ (FAPPLY f = FAPPLY g)`,
REPEAT STRIP_TAC THEN ASM_REWRITE_TAC []);

val NOT_EQ_FEMPTY_FUPDATE = Q.store_thm (
  "NOT_EQ_FEMPTY_FUPDATE",
  `!(f:'a |-> 'b) a b. ~(FEMPTY = FUPDATE f (a,b))`,
  REPEAT GEN_TAC THEN
  DISCH_THEN (MP_TAC o Q.AP_TERM `FDOM`) THEN
  SRW_TAC [][FDOM_FEMPTY, FDOM_FUPDATE, EXTENSION, EXISTS_OR_THM]);

val _ = export_rewrites ["NOT_EQ_FEMPTY_FUPDATE"]

val FDOM_EQ_FDOM_FUPDATE = Q.store_thm(
  "FDOM_EQ_FDOM_FUPDATE",
  `!(f:'a |-> 'b) x. x IN FDOM f ==> (!y. FDOM (FUPDATE f (x,y)) = FDOM f)`,
  SRW_TAC [][FDOM_FUPDATE, EXTENSION, EQ_IMP_THM] THEN
  ASM_REWRITE_TAC []);

(*---------------------------------------------------------------------------
       Simple induction
 ---------------------------------------------------------------------------*)

val fmap_SIMPLE_INDUCT = Q.store_thm ("fmap_SIMPLE_INDUCT",
`!P:('a |-> 'b) -> bool.
     P FEMPTY /\
     (!f. P f ==> !x y. P (FUPDATE f (x,y)))
     ==>
     !f. P f`,
REWRITE_TAC [FUPDATE_DEF, FEMPTY_DEF]
  THEN GEN_TAC THEN STRIP_TAC THEN GEN_TAC
  THEN CHOOSE_THEN(CONJUNCTS_THEN2 SUBST1_TAC MP_TAC) (Q.SPEC`f` fmap_ABS_onto)
  THEN Q.ID_SPEC_TAC `r`
  THEN HO_MATCH_MP_TAC strong_ind
  THEN ASM_REWRITE_TAC []
  THEN Q.PAT_ASSUM `P x` (K ALL_TAC)
  THEN REPEAT STRIP_TAC THEN RES_TAC
  THEN IMP_RES_THEN SUBST_ALL_TAC is_fmap_REP_ABS
  THEN ASM_REWRITE_TAC[]);

val FDOM_EQ_EMPTY = store_thm(
  "FDOM_EQ_EMPTY",
  ``!f. (FDOM f = {}) = (f = FEMPTY)``,
  SIMP_TAC (srw_ss())[EQ_IMP_THM, FDOM_FEMPTY] THEN
  HO_MATCH_MP_TAC fmap_SIMPLE_INDUCT THEN
  SRW_TAC [][FDOM_FUPDATE, EXTENSION] THEN PROVE_TAC []);

val FUPDATE_ABSORB_THM = Q.prove (
  `!(f:'a |-> 'b) x y.
       x IN FDOM f /\ (FAPPLY f x = y) ==> (FUPDATE f (x,y) = f)`,
  INDUCT_THEN fmap_SIMPLE_INDUCT STRIP_ASSUME_TAC THEN
  ASM_SIMP_TAC (srw_ss()) [FDOM_FEMPTY, FDOM_FUPDATE, DISJ_IMP_THM,
                           FORALL_AND_THM] THEN
  REPEAT STRIP_TAC THEN
  Q.ASM_CASES_TAC `x = x'` THENL [
     ASM_SIMP_TAC (srw_ss()) [],
     ASM_SIMP_TAC (srw_ss()) [FAPPLY_FUPDATE_THM] THEN
     FIRST_ASSUM (FREEZE_THEN (fn th => REWRITE_TAC [th]) o
                  MATCH_MP FUPDATE_COMMUTES) THEN
     AP_THM_TAC THEN AP_TERM_TAC THEN FIRST_X_ASSUM MATCH_MP_TAC THEN
     ASM_REWRITE_TAC []
  ]);

val FDOM_FAPPLY = Q.prove
(`!(f:'a |-> 'b) x. x IN FDOM f ==> ?y. FAPPLY f x = y`,
 INDUCT_THEN fmap_SIMPLE_INDUCT ASSUME_TAC THEN
 SRW_TAC [][FDOM_FUPDATE, FDOM_FEMPTY]);

val FDOM_FUPDATE_ABSORB = Q.prove
(`!(f:'a |-> 'b) x. x IN FDOM f ==> ?y. FUPDATE f (x,y) = f`,
 REPEAT STRIP_TAC
   THEN IMP_RES_TAC FDOM_FAPPLY
   THEN Q.EXISTS_TAC `y`
   THEN MATCH_MP_TAC FUPDATE_ABSORB_THM
   THEN ASM_REWRITE_TAC []);

val FDOM_F_FEMPTY = Q.store_thm
("FDOM_F_FEMPTY1",
 `!f:'a |-> 'b. (!a. ~(a IN FDOM f)) = (f = FEMPTY)`,
 HO_MATCH_MP_TAC fmap_SIMPLE_INDUCT THEN
 SRW_TAC [][FDOM_FEMPTY, FDOM_FUPDATE, NOT_EQ_FEMPTY_FUPDATE, EXISTS_OR_THM]);

val FDOM_FINITE = store_thm(
  "FDOM_FINITE",
  ``!fm. FINITE (FDOM fm)``,
   HO_MATCH_MP_TAC fmap_SIMPLE_INDUCT THEN
   SRW_TAC [][FDOM_FEMPTY, FDOM_FUPDATE]);

val _ = export_rewrites ["FDOM_FINITE"]

(* ===================================================================== *)
(* Cardinality                                                           *)
(*                                                                       *)
(* Define cardinality as the cardinality of the domain of the map        *)
(* ===================================================================== *)

val FCARD_DEF = new_definition("FCARD_DEF", ``FCARD fm = CARD (FDOM fm)``);

(* --------------------------------------------------------------------- *)
(* Basic cardinality results.                                            *)
(* --------------------------------------------------------------------- *)

val FCARD_FEMPTY = store_thm(
  "FCARD_FEMPTY",
  ``FCARD FEMPTY = 0``,
  SRW_TAC [][FCARD_DEF, FDOM_FEMPTY]);

val FCARD_FUPDATE = store_thm(
  "FCARD_FUPDATE",
  ``!fm a b. FCARD (FUPDATE fm (a, b)) = if a IN FDOM fm then FCARD fm
                                         else 1 + FCARD fm``,
  SRW_TAC [numSimps.ARITH_ss][FCARD_DEF, FDOM_FUPDATE, FDOM_FINITE]);

val FCARD_0_FEMPTY_LEMMA = Q.prove
(`!f. (FCARD f = 0) ==> (f = FEMPTY)`,
 INDUCT_THEN fmap_SIMPLE_INDUCT ASSUME_TAC THEN
 SRW_TAC [numSimps.ARITH_ss][NOT_EQ_FEMPTY_FUPDATE, FCARD_FUPDATE] THEN
 STRIP_TAC THEN RES_TAC THEN
 FULL_SIMP_TAC (srw_ss()) [FDOM_FEMPTY]);

val fmap = ``f : 'a |-> 'b``

val FCARD_0_FEMPTY = Q.store_thm("FCARD_0_FEMPTY",
`!^fmap. (FCARD f = 0) = (f = FEMPTY)`,
GEN_TAC THEN EQ_TAC THENL
[REWRITE_TAC [FCARD_0_FEMPTY_LEMMA],
 DISCH_THEN (fn th => ASM_REWRITE_TAC [th, FCARD_FEMPTY])]);

val FCARD_SUC = store_thm(
  "FCARD_SUC",
  ``!f n. (FCARD f = SUC n) = (?f' x y. ~(x IN FDOM f') /\ (FCARD f' = n) /\
                                        (f = FUPDATE f' (x, y)))``,
  SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss)
           [EQ_IMP_THM, FORALL_AND_THM, GSYM LEFT_FORALL_IMP_THM,
            FCARD_FUPDATE] THEN
  HO_MATCH_MP_TAC fmap_SIMPLE_INDUCT THEN
  SIMP_TAC (srw_ss() ++ numSimps.ARITH_ss)[FCARD_FUPDATE, FCARD_FEMPTY] THEN
  GEN_TAC THEN STRIP_TAC THEN REPEAT GEN_TAC THEN
  COND_CASES_TAC THEN STRIP_TAC THENL [
    RES_THEN (EVERY_TCL
                (map Q.X_CHOOSE_THEN [`g`, `u`, `v`]) STRIP_ASSUME_TAC) THEN
    Q.ASM_CASES_TAC `x = u` THENL [
      MAP_EVERY Q.EXISTS_TAC [`g`, `u`, `y`] THEN
      ASM_SIMP_TAC (srw_ss()) [],
      MAP_EVERY Q.EXISTS_TAC [`FUPDATE g (x, y)`, `u`, `v`] THEN
      `x IN FDOM g` by FULL_SIMP_TAC (srw_ss()) [FDOM_FUPDATE] THEN
      ASM_SIMP_TAC (srw_ss()) [FDOM_FUPDATE, FCARD_FUPDATE, FUPDATE_COMMUTES]
    ],
    MAP_EVERY Q.EXISTS_TAC [`f`, `x`, `y`] THEN
    SRW_TAC [numSimps.ARITH_ss][]
  ]);

(*---------------------------------------------------------------------------
         A more useful induction theorem
 ---------------------------------------------------------------------------*)

val fmap_INDUCT = Q.store_thm(
  "fmap_INDUCT",
  `!P. P FEMPTY /\
       (!f. P f ==> !x y. ~(x IN FDOM f) ==> P (FUPDATE f (x,y)))
          ==>
       !f. P f`,
  REPEAT STRIP_TAC THEN Induct_on `FCARD f` THEN REPEAT STRIP_TAC THENL [
    PROVE_TAC [FCARD_0_FEMPTY],
    `?g u w. ~(u IN FDOM g) /\ (f = FUPDATE g (u, w)) /\ (FCARD g = v)` by
       PROVE_TAC [FCARD_SUC] THEN
    PROVE_TAC []
  ]);

(* splitting a finite map on a key *)
val FM_PULL_APART = store_thm(
  "FM_PULL_APART",
  ``!fm k. k IN FDOM fm ==> ?fm0 v. (fm = fm0 |+ (k, v)) /\
                                    ~(k IN FDOM fm0)``,
  HO_MATCH_MP_TAC fmap_INDUCT THEN SRW_TAC [][] THENL [
    PROVE_TAC [],
    RES_TAC THEN
    MAP_EVERY Q.EXISTS_TAC [`fm0 |+ (x,y)`, `v`] THEN
    `~(k = x)` by PROVE_TAC [] THEN
    SRW_TAC [][FUPDATE_COMMUTES]
  ]);


(*---------------------------------------------------------------------------
     Equality of finite maps
 ---------------------------------------------------------------------------*)

val update_eq_not_x = Q.prove
(`!(f:'a |-> 'b) x.
      ?f'. !y. (FUPDATE f (x,y) = FUPDATE f' (x,y)) /\ ~(x IN FDOM f')`,
 HO_MATCH_MP_TAC fmap_INDUCT THEN SRW_TAC [][] THENL [
   Q.EXISTS_TAC `FEMPTY` THEN SRW_TAC [][],
   FIRST_X_ASSUM (Q.SPEC_THEN `x'` STRIP_ASSUME_TAC) THEN
   Cases_on `x = x'` THEN SRW_TAC [][] THENL [
     Q.EXISTS_TAC `f` THEN SRW_TAC [][],
     Q.EXISTS_TAC `f' |+ (x,y)` THEN
     SRW_TAC [][] THEN METIS_TAC [FUPDATE_COMMUTES]
   ]
 ])

val lemma9 = BETA_RULE (Q.prove
(`!x y (f1:('a,'b)fmap) f2.
   (f1 = f2) ==>
    ((\f.FUPDATE f (x,y)) f1 = (\f. FUPDATE f (x,y)) f2)`,
 REPEAT STRIP_TAC
   THEN AP_TERM_TAC
   THEN ASM_REWRITE_TAC []));

val NOT_FDOM_FAPPLY_FEMPTY = Q.store_thm
("NOT_FDOM_FAPPLY_FEMPTY",
 `!^fmap x. ~(x IN FDOM f) ==> (FAPPLY f x = FAPPLY FEMPTY x)`,
 INDUCT_THEN fmap_INDUCT ASSUME_TAC THENL
 [REWRITE_TAC [],
  REPEAT GEN_TAC
    THEN STRIP_TAC
    THEN GEN_TAC
    THEN Q.ASM_CASES_TAC `x' = x` THENL
    [ASM_REWRITE_TAC [FDOM_FUPDATE, IN_INSERT],
     IMP_RES_TAC NOT_EQ_FAPPLY
       THEN ASM_REWRITE_TAC [FDOM_FUPDATE, IN_INSERT]]]);

val fmap_EQ_2 = Q.prove(
  `!(f:'a |-> 'b) g. (FDOM f = FDOM g) /\ (FAPPLY f = FAPPLY g) ==> (f = g)`,
  INDUCT_THEN fmap_INDUCT ASSUME_TAC THENL [
    SRW_TAC [][FDOM_FEMPTY] THEN
    PROVE_TAC [FCARD_0_FEMPTY, CARD_EMPTY, FCARD_DEF],
    SRW_TAC [][FDOM_FUPDATE] THEN
    `?h. (FUPDATE g (x, g ' x) = FUPDATE h (x, g ' x)) /\ ~(x IN FDOM h)`
       by PROVE_TAC [update_eq_not_x] THEN
    `x IN FDOM g` by PROVE_TAC [IN_INSERT] THEN
    `FUPDATE g (x, g ' x) = g` by PROVE_TAC [FUPDATE_ABSORB_THM] THEN
    POP_ASSUM SUBST_ALL_TAC THEN FIRST_X_ASSUM SUBST_ALL_TAC THEN
    `!v. (f |+ (x, y)) ' v = (h |+ (x, FAPPLY g x)) ' v`
        by SRW_TAC [][] THEN
    `y = g ' x` by PROVE_TAC [FAPPLY_FUPDATE] THEN
    ASM_REWRITE_TAC [] THEN AP_THM_TAC THEN AP_TERM_TAC THEN
    FIRST_X_ASSUM MATCH_MP_TAC THEN CONJ_TAC THENL [
      FULL_SIMP_TAC (srw_ss()) [EXTENSION, FDOM_FUPDATE] THEN PROVE_TAC [],
      SIMP_TAC (srw_ss()) [FUN_EQ_THM] THEN Q.X_GEN_TAC `z` THEN
      Cases_on `x = z` THENL [
        PROVE_TAC [NOT_FDOM_FAPPLY_FEMPTY],
        FIRST_X_ASSUM (Q.SPEC_THEN `z` MP_TAC) THEN
        ASM_SIMP_TAC (srw_ss()) [FAPPLY_FUPDATE_THM]
      ]
    ]
  ]);

val fmap_EQ = Q.store_thm
("fmap_EQ",
 `!(f:'a |-> 'b) g. (FDOM f = FDOM g) /\ (FAPPLY f = FAPPLY g) = (f = g)`,
 REPEAT STRIP_TAC THEN EQ_TAC THEN REWRITE_TAC [fmap_EQ_1, fmap_EQ_2]);

(*---------------------------------------------------------------------------
       A more useful equality
 ---------------------------------------------------------------------------*)

val fmap_EQ_THM = Q.store_thm
("fmap_EQ_THM",
 `!(f:'a |-> 'b) g.
    (FDOM f = FDOM g) /\ (!x. x IN FDOM f ==> (FAPPLY f x = FAPPLY g x))
                       =
                    (f = g)`,
 REPEAT STRIP_TAC THEN EQ_TAC THENL [
   STRIP_TAC THEN ASM_REWRITE_TAC [GSYM fmap_EQ] THEN
   MATCH_MP_TAC EQ_EXT THEN GEN_TAC THEN
   Q.ASM_CASES_TAC `x IN FDOM f` THEN PROVE_TAC [NOT_FDOM_FAPPLY_FEMPTY],
   STRIP_TAC THEN ASM_REWRITE_TAC []
 ]);

(* and it's more useful still if the main equality is the other way 'round *)
val fmap_EXT = save_thm("fmap_EXT", GSYM fmap_EQ_THM)


(*---------------------------------------------------------------------------
           Submaps
 ---------------------------------------------------------------------------*)

val SUBMAP_DEF = new_infixr_definition
("SUBMAP_DEF",
 Term`!^fmap g.
         $SUBMAP f g =
          !x. x IN FDOM f ==> x IN FDOM g /\ (FAPPLY f x = FAPPLY g x)`, 450);


val SUBMAP_FEMPTY = Q.store_thm
("SUBMAP_FEMPTY",
 `!(f : ('a,'b) fmap). FEMPTY SUBMAP f`,
 SRW_TAC [][SUBMAP_DEF, FDOM_FEMPTY]);

val SUBMAP_REFL = Q.store_thm
("SUBMAP_REFL",
 `!(f:('a,'b) fmap). f SUBMAP  f`,
 REWRITE_TAC [SUBMAP_DEF]);

val SUBMAP_ANTISYM = Q.store_thm
("SUBMAP_ANTISYM",
 `!(f:('a,'b) fmap) g. (f SUBMAP g /\ g SUBMAP f) = (f = g)`,
 GEN_TAC THEN GEN_TAC THEN EQ_TAC THENL [
   REWRITE_TAC[SUBMAP_DEF, GSYM fmap_EQ_THM, EXTENSION] THEN PROVE_TAC [],
   STRIP_TAC THEN ASM_REWRITE_TAC [SUBMAP_REFL]
 ]);

val SUBMAP_TRANS = store_thm(
  "SUBMAP_TRANS",
  ``!f g h. f SUBMAP g /\ g SUBMAP h ==> f SUBMAP h``,
  SRW_TAC [][SUBMAP_DEF]);


(*---------------------------------------------------------------------------
    Restriction
 ---------------------------------------------------------------------------*)

val res_lemma = Q.prove
(`!^fmap r.
     ?res. (FDOM res = FDOM f INTER r)
       /\  (!x. FAPPLY res x =
                 if x IN FDOM f INTER r then FAPPLY f x else FAPPLY FEMPTY x)`,
 CONV_TAC SWAP_VARS_CONV THEN GEN_TAC THEN
 INDUCT_THEN fmap_INDUCT STRIP_ASSUME_TAC THENL [
   Q.EXISTS_TAC `FEMPTY` THEN SRW_TAC [][FDOM_FEMPTY],
   REPEAT STRIP_TAC THEN
   Cases_on `x IN r` THENL [
     Q.EXISTS_TAC `FUPDATE res (x,y)` THEN
     ASM_SIMP_TAC (srw_ss()) [FDOM_FUPDATE, FAPPLY_FUPDATE_THM, EXTENSION] THEN
     SRW_TAC [][] THEN FULL_SIMP_TAC (srw_ss()) [] THEN PROVE_TAC [],

     Q.EXISTS_TAC `res` THEN
     SRW_TAC [][FDOM_FUPDATE, FAPPLY_FUPDATE_THM, EXTENSION] THEN
     FULL_SIMP_TAC (srw_ss()) [] THEN PROVE_TAC []
   ]
 ]);

val DRESTRICT_DEF = new_specification
  ("DRESTRICT_DEF", ["DRESTRICT"],
   CONV_RULE (ONCE_DEPTH_CONV SKOLEM_CONV) res_lemma);


val DRESTRICT_FEMPTY = Q.store_thm
("DRESTRICT_FEMPTY",
 `!r. DRESTRICT FEMPTY r = FEMPTY`,
 SRW_TAC [][GSYM fmap_EQ_THM, DRESTRICT_DEF, FDOM_FEMPTY]);
val _ = export_rewrites ["DRESTRICT_FEMPTY"]

val DRESTRICT_FUPDATE = Q.store_thm
("DRESTRICT_FUPDATE",
 `!^fmap r x y.
     DRESTRICT (FUPDATE f (x,y)) r =
        if x IN r then FUPDATE (DRESTRICT f r) (x,y) else DRESTRICT f r`,
 SRW_TAC [][GSYM fmap_EQ_THM, FDOM_FUPDATE, DRESTRICT_DEF, FAPPLY_FUPDATE_THM,
            EXTENSION] THEN PROVE_TAC []);
val _ = export_rewrites ["DRESTRICT_FUPDATE"]


val STRONG_DRESTRICT_FUPDATE = Q.store_thm
("STRONG_DRESTRICT_FUPDATE",
 `!^fmap r x y.
      x IN r ==> (DRESTRICT (FUPDATE f (x,y)) r
                    =
                  FUPDATE (DRESTRICT f (r DELETE x)) (x,y))`,
 SRW_TAC [][GSYM fmap_EQ_THM, FDOM_FUPDATE, DRESTRICT_DEF,
            FAPPLY_FUPDATE_THM, EXTENSION] THEN PROVE_TAC []);

val FDOM_DRESTRICT = Q.store_thm (
  "FDOM_DRESTRICT",
  `!^fmap r x. FDOM (DRESTRICT f r) = FDOM f INTER r`,
  SRW_TAC [][DRESTRICT_DEF]);

val NOT_FDOM_DRESTRICT = Q.store_thm
("NOT_FDOM_DRESTRICT",
 `!^fmap x. ~(x IN FDOM f) ==> (DRESTRICT f (COMPL {x}) = f)`,
 SRW_TAC [][GSYM fmap_EQ_THM, DRESTRICT_DEF, EXTENSION] THEN PROVE_TAC []);

val DRESTRICT_SUBMAP = Q.store_thm
("DRESTRICT_SUBMAP",
 `!^fmap r. (DRESTRICT f r) SUBMAP f`,
 INDUCT_THEN fmap_INDUCT STRIP_ASSUME_TAC THENL [
   REWRITE_TAC [DRESTRICT_FEMPTY, SUBMAP_FEMPTY],
   POP_ASSUM MP_TAC THEN
   SIMP_TAC (srw_ss()) [DRESTRICT_DEF, SUBMAP_DEF, FDOM_FUPDATE]
 ]);

val DRESTRICT_DRESTRICT = Q.store_thm
("DRESTRICT_DRESTRICT",
 `!^fmap P Q. DRESTRICT (DRESTRICT f P) Q = DRESTRICT f (P INTER Q)`,
 HO_MATCH_MP_TAC fmap_INDUCT
   THEN SRW_TAC [][DRESTRICT_FEMPTY, DRESTRICT_FUPDATE]
   THEN Q.ASM_CASES_TAC `x IN P`
   THEN Q.ASM_CASES_TAC `x IN Q`
   THEN ASM_REWRITE_TAC [DRESTRICT_FUPDATE]);

val DRESTRICT_IS_FEMPTY = Q.store_thm
("DRESTRICT_IS_FEMPTY",
 `!f. DRESTRICT f {} = FEMPTY`,
 GEN_TAC THEN
 `FDOM (DRESTRICT f {}) = {}` by SRW_TAC [][FDOM_DRESTRICT] THEN
 PROVE_TAC [FDOM_EQ_EMPTY]);

val FUPDATE_DRESTRICT = Q.store_thm
("FUPDATE_DRESTRICT",
 `!^fmap x y. FUPDATE f (x,y) = FUPDATE (DRESTRICT f (COMPL {x})) (x,y)`,
 SRW_TAC [][GSYM fmap_EQ_THM, FDOM_FUPDATE, EXTENSION, DRESTRICT_DEF,
            FAPPLY_FUPDATE_THM] THEN PROVE_TAC []);

val STRONG_DRESTRICT_FUPDATE_THM = Q.store_thm
("STRONG_DRESTRICT_FUPDATE_THM",
 `!^fmap r x y.
  DRESTRICT (FUPDATE f (x,y)) r
     =
  if x IN r then FUPDATE (DRESTRICT f (COMPL {x} INTER r)) (x,y)
  else DRESTRICT f (COMPL {x} INTER r)`,
 SRW_TAC [][GSYM fmap_EQ_THM, DRESTRICT_DEF, FDOM_FUPDATE, EXTENSION,
            FAPPLY_FUPDATE_THM] THEN PROVE_TAC []);

val DRESTRICT_UNIV = Q.store_thm
("DRESTRICT_UNIV",
 `!^fmap. DRESTRICT f UNIV = f`,
 SRW_TAC [][DRESTRICT_DEF, GSYM fmap_EQ_THM]);

(*---------------------------------------------------------------------------
     Union of finite maps
 ---------------------------------------------------------------------------*)

val union_lemma = Q.prove
(`!^fmap g.
     ?union.
       (FDOM union = FDOM f UNION FDOM g) /\
       (!x. FAPPLY union x = if x IN FDOM f then FAPPLY f x else FAPPLY g x)`,
 INDUCT_THEN fmap_INDUCT ASSUME_TAC THENL [
   GEN_TAC THEN Q.EXISTS_TAC `g` THEN SRW_TAC [][FDOM_FEMPTY],
   REPEAT STRIP_TAC THEN
   FIRST_X_ASSUM (Q.SPEC_THEN `g` STRIP_ASSUME_TAC) THEN
   Q.EXISTS_TAC `FUPDATE union (x,y)` THEN
   SRW_TAC [][FDOM_FUPDATE, FAPPLY_FUPDATE_THM, EXTENSION] THEN
   PROVE_TAC []
 ]);

val FUNION_DEF = new_specification
  ("FUNION_DEF", ["FUNION"],
   CONV_RULE (ONCE_DEPTH_CONV SKOLEM_CONV) union_lemma);

val FUNION_FEMPTY_1 = Q.store_thm
("FUNION_FEMPTY_1",
 `!g. FUNION FEMPTY g = g`,
 SRW_TAC [][GSYM fmap_EQ_THM, FUNION_DEF, FDOM_FEMPTY]);

val FUNION_FEMPTY_2 = Q.store_thm
("FUNION_FEMPTY_2",
 `!f. FUNION f FEMPTY = f`,
 SRW_TAC [][GSYM fmap_EQ_THM, FUNION_DEF, FDOM_FEMPTY]);

val FUNION_FUPDATE_1 = Q.store_thm
("FUNION_FUPDATE_1",
 `!^fmap g x y.
     FUNION (FUPDATE f (x,y)) g = FUPDATE (FUNION f g) (x,y)`,
 SRW_TAC [][GSYM fmap_EQ_THM, FDOM_FUPDATE, FUNION_DEF, FAPPLY_FUPDATE_THM,
            EXTENSION] THEN PROVE_TAC []);

val FUNION_FUPDATE_2 = Q.store_thm
("FUNION_FUPDATE_2",
 `!^fmap g x y.
     FUNION f (FUPDATE g (x,y)) =
        if x IN FDOM f then FUNION f g
        else FUPDATE (FUNION f g) (x,y)`,
 SRW_TAC [][GSYM fmap_EQ_THM, FDOM_FUPDATE, FUNION_DEF, FAPPLY_FUPDATE_THM,
            EXTENSION] THEN PROVE_TAC []);

val FDOM_FUNION = Q.store_thm
("FDOM_FUNION",
 `!^fmap g x. FDOM (FUNION f g) = FDOM f UNION FDOM g`,
 REWRITE_TAC [FUNION_DEF]);

val DRESTRICT_FUNION = Q.store_thm
("DRESTRICT_FUNION",
 `!^fmap r q.
     DRESTRICT f (r UNION q) = FUNION (DRESTRICT f r) (DRESTRICT f q)`,
 SRW_TAC [][GSYM fmap_EQ_THM, FDOM_FUPDATE, FUNION_DEF, FAPPLY_FUPDATE_THM,
            EXTENSION, DRESTRICT_DEF] THEN PROVE_TAC []);


(*---------------------------------------------------------------------------
    "assoc" for finite maps
 ---------------------------------------------------------------------------*)

val FLOOKUP_DEF = Q.new_definition
("FLOOKUP_DEF",
 `FLOOKUP ^fmap x = if x IN FDOM f then SOME (FAPPLY f x) else NONE`);

val FLOOKUP_EMPTY = store_thm(
  "FLOOKUP_EMPTY",
  ``FLOOKUP FEMPTY k = NONE``,
  SRW_TAC [][FLOOKUP_DEF]);
val _ = export_rewrites ["FLOOKUP_EMPTY"]

val FLOOKUP_UPDATE = store_thm(
  "FLOOKUP_UPDATE",
  ``FLOOKUP (fm |+ (k1,v)) k2 = if k1 = k2 then SOME v else FLOOKUP fm k2``,
  SRW_TAC [][FLOOKUP_DEF, FAPPLY_FUPDATE_THM] THEN
  FULL_SIMP_TAC (srw_ss()) []);
(* don't export this because of the if, though this is pretty paranoid *)


(*---------------------------------------------------------------------------
       Universal quantifier on finite maps
 ---------------------------------------------------------------------------*)

val FEVERY_DEF = Q.new_definition
("FEVERY_DEF",
 `FEVERY P ^fmap = !x. x IN FDOM f ==> P (x, FAPPLY f x)`);

val FEVERY_FEMPTY = Q.store_thm
("FEVERY_FEMPTY",
 `!P:'a#'b -> bool. FEVERY P FEMPTY`,
 SRW_TAC [][FEVERY_DEF, FDOM_FEMPTY]);

val FEVERY_FUPDATE = Q.store_thm
("FEVERY_FUPDATE",
 `!P ^fmap x y.
     FEVERY P (FUPDATE f (x,y))
        =
     P (x,y) /\ FEVERY P (DRESTRICT f (COMPL {x}))`,
 SRW_TAC [][FEVERY_DEF, FDOM_FUPDATE, FAPPLY_FUPDATE_THM,
            DRESTRICT_DEF, EQ_IMP_THM] THEN PROVE_TAC []);

(*---------------------------------------------------------------------------
      Composition of finite maps
 ---------------------------------------------------------------------------*)

val f_o_f_lemma = Q.prove
(`!f:'b |-> 'c.
  !g:'a |-> 'b.
     ?comp. (FDOM comp = FDOM g INTER { x | FAPPLY g x IN FDOM f })
       /\   (!x. x IN FDOM comp ==>
                    (FAPPLY comp x = (FAPPLY f (FAPPLY g x))))`,
 GEN_TAC THEN INDUCT_THEN fmap_INDUCT STRIP_ASSUME_TAC THENL [
   Q.EXISTS_TAC `FEMPTY` THEN SRW_TAC [][FDOM_FEMPTY],
   REPEAT STRIP_TAC THEN
   Cases_on  `y IN FDOM f` THENL [
     Q.EXISTS_TAC `FUPDATE comp (x, FAPPLY f y)` THEN
     SRW_TAC [][FDOM_FUPDATE, FAPPLY_FUPDATE_THM, EXTENSION] THEN
     PROVE_TAC [],
     Q.EXISTS_TAC `comp` THEN
     SRW_TAC [][FDOM_FUPDATE, FAPPLY_FUPDATE_THM, EXTENSION] THEN
     PROVE_TAC []
   ]
 ]);

val f_o_f_DEF = new_specification
  ("f_o_f_DEF", ["f_o_f"],
   CONV_RULE (ONCE_DEPTH_CONV SKOLEM_CONV) f_o_f_lemma);

val _ = set_fixity "f_o_f" (Infixl 500);

val f_o_f_FEMPTY_1 = Q.store_thm
("f_o_f_FEMPTY_1",
 `!^fmap. (FEMPTY:('b,'c)fmap) f_o_f f = FEMPTY`,
 SRW_TAC [][GSYM fmap_EQ_THM, f_o_f_DEF, FDOM_FEMPTY, EXTENSION]);

val f_o_f_FEMPTY_2 = Q.store_thm (
  "f_o_f_FEMPTY_2",
  `!f:'b|->'c. f f_o_f (FEMPTY:('a,'b)fmap) = FEMPTY`,
  SRW_TAC [][GSYM fmap_EQ_THM, f_o_f_DEF, FDOM_FEMPTY]);

val o_f_lemma = Q.prove
(`!f:'b->'c.
  !g:'a|->'b.
    ?comp. (FDOM comp = FDOM g)
      /\   (!x. x IN FDOM comp ==> (FAPPLY comp x = f (FAPPLY g x)))`,
 GEN_TAC THEN INDUCT_THEN fmap_INDUCT STRIP_ASSUME_TAC THENL [
   Q.EXISTS_TAC `FEMPTY` THEN SRW_TAC [][FDOM_FEMPTY],
   REPEAT STRIP_TAC THEN Q.EXISTS_TAC `FUPDATE comp (x, f y)` THEN
   SRW_TAC [][FDOM_FUPDATE, FAPPLY_FUPDATE_THM]
 ]);

val o_f_DEF = new_specification
  ("o_f_DEF", ["o_f"],
   CONV_RULE (ONCE_DEPTH_CONV SKOLEM_CONV) o_f_lemma);

val _ = set_fixity "o_f" (Infixl 500);

val o_f_FDOM = Q.store_thm
("o_f_FDOM",
 `!f:'b -> 'c. !g:'a |->'b. FDOM  g = FDOM (f o_f g)`,
REWRITE_TAC [o_f_DEF]);

val FDOM_o_f = save_thm("FDOM_o_f", GSYM o_f_FDOM);
val _ = BasicProvers.export_rewrites ["FDOM_o_f"]

val o_f_FAPPLY = Q.store_thm
("o_f_FAPPLY",
 `!f:'b->'c. !g:('a,'b) fmap.
   !x. x IN FDOM  g ==> (FAPPLY (f o_f g) x = f (FAPPLY g x))`,
 SRW_TAC [][o_f_DEF]);

val o_f_FEMPTY = store_thm(
  "o_f_FEMPTY",
  ``f o_f FEMPTY = FEMPTY``,
  SRW_TAC [][GSYM fmap_EQ_THM, FDOM_o_f])
val _ = BasicProvers.export_rewrites ["o_f_FEMPTY"]

val o_f_o_f = store_thm(
  "o_f_o_f",
  ``(f o_f (g o_f h)) = (f o g) o_f h``,
  SRW_TAC [][GSYM fmap_EQ_THM, o_f_FAPPLY]);
val _ = export_rewrites ["o_f_o_f"]


(*---------------------------------------------------------------------------
          Range of a finite map
 ---------------------------------------------------------------------------*)

val FRANGE_DEF = Q.new_definition
("FRANGE_DEF",
 `FRANGE ^fmap = { y | ?x. x IN FDOM f /\ (FAPPLY f x = y)}`);

val FRANGE_FEMPTY = Q.store_thm
("FRANGE_FEMPTY",
 `FRANGE FEMPTY = {}`,
 SRW_TAC [][FRANGE_DEF, FDOM_FEMPTY, EXTENSION]);
val _ = export_rewrites ["FRANGE_FEMPTY"]

val FRANGE_FUPDATE = Q.store_thm
("FRANGE_FUPDATE",
 `!^fmap x y.
     FRANGE (FUPDATE f (x,y))
       =
     y INSERT FRANGE (DRESTRICT f (COMPL {x}))`,
 SRW_TAC [][FRANGE_DEF, FDOM_FUPDATE, DRESTRICT_DEF, EXTENSION,
            FAPPLY_FUPDATE_THM] THEN PROVE_TAC []);

val SUBMAP_FRANGE = Q.store_thm
("SUBMAP_FRANGE",
 `!^fmap g. f SUBMAP g ==> FRANGE f SUBSET FRANGE g`,
 SRW_TAC [][SUBMAP_DEF,FRANGE_DEF, SUBSET_DEF] THEN PROVE_TAC []);

val FINITE_FRANGE = store_thm(
  "FINITE_FRANGE",
  ``!fm. FINITE (FRANGE fm)``,
  HO_MATCH_MP_TAC fmap_INDUCT THEN
  SRW_TAC [][FRANGE_FUPDATE] THEN
  Q_TAC SUFF_TAC `DRESTRICT fm (COMPL {x}) = fm` THEN1 SRW_TAC [][] THEN
  SRW_TAC [][GSYM fmap_EQ_THM, DRESTRICT_DEF, EXTENSION] THEN
  PROVE_TAC []);
val _ = export_rewrites ["FINITE_FRANGE"]

(*---------------------------------------------------------------------------
        Range restriction
 ---------------------------------------------------------------------------*)

val ranres_lemma = Q.prove
(`!^fmap (r:'b set).
    ?res. (FDOM res = { x | x IN FDOM f /\ FAPPLY f x IN r})
      /\  (!x. FAPPLY res x =
                 if x IN FDOM f /\ FAPPLY f x IN r
                   then FAPPLY f x
                   else FAPPLY FEMPTY x)`,
 CONV_TAC SWAP_VARS_CONV THEN GEN_TAC THEN
 INDUCT_THEN fmap_INDUCT STRIP_ASSUME_TAC THENL [
   Q.EXISTS_TAC `FEMPTY` THEN SRW_TAC [][FDOM_FEMPTY, EXTENSION],
   REPEAT STRIP_TAC THEN
   Cases_on `y IN r` THENL [
     Q.EXISTS_TAC `FUPDATE res (x,y)` THEN
     SRW_TAC [][FDOM_FUPDATE, FAPPLY_FUPDATE_THM, EXTENSION] THEN
     PROVE_TAC [],
     Q.EXISTS_TAC `res` THEN
     SRW_TAC [][FDOM_FUPDATE, FAPPLY_FUPDATE_THM, EXTENSION] THEN
     PROVE_TAC []
   ]
 ]);

val RRESTRICT_DEF = new_specification
  ("RRESTRICT_DEF", ["RRESTRICT"],
   CONV_RULE (ONCE_DEPTH_CONV SKOLEM_CONV) ranres_lemma);

val RRESTRICT_FEMPTY = Q.store_thm
("RRESTRICT_FEMPTY",
 `!r. RRESTRICT FEMPTY r = FEMPTY`,
 SRW_TAC [][GSYM fmap_EQ_THM, RRESTRICT_DEF, FDOM_FEMPTY, EXTENSION]);

val RRESTRICT_FUPDATE = Q.store_thm
("RRESTRICT_FUPDATE",
`!^fmap r x y.
    RRESTRICT (FUPDATE f (x,y)) r =
      if y IN r then FUPDATE (RRESTRICT f r) (x,y)
      else RRESTRICT (DRESTRICT f (COMPL {x})) r`,
 SRW_TAC [][GSYM fmap_EQ_THM, FDOM_FUPDATE, RRESTRICT_DEF, DRESTRICT_DEF,
            EXTENSION, FAPPLY_FUPDATE_THM] THEN PROVE_TAC []);

(*---------------------------------------------------------------------------
       Functions as finite maps.

 ---------------------------------------------------------------------------*)

val ffmap_lemma = Q.prove
(`!(f:'a -> 'b) (P: 'a set).
     FINITE P ==>
        ?ffmap. (FDOM ffmap = P)
           /\   (!x. x IN P ==> (FAPPLY ffmap x = f x))`,
 GEN_TAC THEN HO_MATCH_MP_TAC FINITE_INDUCT THEN CONJ_TAC THENL [
   Q.EXISTS_TAC `FEMPTY` THEN BETA_TAC THEN
   REWRITE_TAC [FDOM_FEMPTY, NOT_IN_EMPTY],
   REPEAT STRIP_TAC THEN Q.EXISTS_TAC `FUPDATE ffmap (e, f e)` THEN
   ASM_REWRITE_TAC [FDOM_FUPDATE, IN_INSERT, FAPPLY_FUPDATE_THM] THEN
   REPEAT STRIP_TAC THEN ASM_REWRITE_TAC [] THEN
   COND_CASES_TAC THENL [
     POP_ASSUM SUBST_ALL_TAC THEN RES_TAC,
     FIRST_ASSUM MATCH_MP_TAC THEN ASM_REWRITE_TAC []
   ]
 ]);

val FUN_FMAP_DEF = new_specification
  ("FUN_FMAP_DEF", ["FUN_FMAP"],
   CONV_RULE (ONCE_DEPTH_CONV RIGHT_IMP_EXISTS_CONV THENC
              ONCE_DEPTH_CONV SKOLEM_CONV) ffmap_lemma);

val FUN_FMAP_EMPTY = store_thm(
  "FUN_FMAP_EMPTY",
  ``FUN_FMAP f {} = FEMPTY``,
  SRW_TAC [][GSYM fmap_EQ_THM, FUN_FMAP_DEF]);
val _ = export_rewrites ["FUN_FMAP_EMPTY"]

val FRANGE_FMAP = store_thm(
  "FRANGE_FMAP",
  ``FINITE P ==> (FRANGE (FUN_FMAP f P) = IMAGE f P)``,
  SRW_TAC [boolSimps.CONJ_ss][EXTENSION, FRANGE_DEF, FUN_FMAP_DEF] THEN
  PROVE_TAC []);
val _ = export_rewrites ["FRANGE_FMAP"]



(*---------------------------------------------------------------------------
         Composition of finite map and function
 ---------------------------------------------------------------------------*)

val f_o_DEF = new_infixl_definition
("f_o_DEF",
Term`$f_o (f:('b,'c)fmap) (g:'a->'b)
      = f f_o_f (FUN_FMAP g { x | g x IN FDOM f})`, 500);

val FDOM_f_o = Q.store_thm
("FDOM_f_o",
 `!(f:'b|->'c)  (g:'a->'b).
     FINITE {x | g x IN FDOM f }
       ==>
     (FDOM (f f_o g) = { x | g x IN FDOM f})`,
 SRW_TAC [][f_o_DEF, f_o_f_DEF, EXTENSION, FUN_FMAP_DEF, EQ_IMP_THM]);

val FAPPLY_f_o = Q.store_thm
("FAPPLY_f_o",
 `!(f:'b |-> 'c)  (g:'a-> 'b).
    FINITE { x | g x IN FDOM f }
      ==>
    !x. x IN FDOM (f f_o g) ==> (FAPPLY (f f_o g) x = FAPPLY f (g x))`,
 SRW_TAC [][FDOM_f_o, FUN_FMAP_DEF, f_o_DEF, f_o_f_DEF]);


val FINITE_PRED_11 = Q.store_thm
("FINITE_PRED_11",
 `!(g:'a -> 'b).
      (!x y. (g x = g y) = (x = y))
        ==>
      !f:'b|->'c. FINITE { x | g x IN  FDOM f}`,
 GEN_TAC THEN STRIP_TAC THEN
 INDUCT_THEN fmap_INDUCT ASSUME_TAC THENL [
   SRW_TAC [][FDOM_FEMPTY, GSPEC_F],
   SRW_TAC [][FDOM_FUPDATE, GSPEC_OR] THEN
   Cases_on `?y. g y = x` THENL [
     POP_ASSUM (STRIP_THM_THEN SUBST_ALL_TAC o GSYM) THEN
     SRW_TAC [][GSPEC_EQ],
     POP_ASSUM MP_TAC THEN SRW_TAC [][GSPEC_F]
   ]
 ]);

(* ----------------------------------------------------------------------
    Domain subtraction (at a single point)
   ---------------------------------------------------------------------- *)

val fmap_domsub = new_definition(
  "fmap_domsub",
  ``(\\) fm k = DRESTRICT fm (COMPL {k})``);

val DOMSUB_FEMPTY = store_thm(
  "DOMSUB_FEMPTY",
  ``!k. FEMPTY \\ k = FEMPTY``,
  SRW_TAC [][GSYM fmap_EQ_THM, fmap_domsub, FDOM_DRESTRICT]);

val DOMSUB_FUPDATE = store_thm(
  "DOMSUB_FUPDATE",
  ``!fm k v. fm |+ (k,v) \\ k = fm \\ k``,
  SRW_TAC [][GSYM fmap_EQ_THM, fmap_domsub,
             pred_setTheory.EXTENSION, DRESTRICT_DEF,
             FAPPLY_FUPDATE_THM] THEN PROVE_TAC []);

val DOMSUB_FUPDATE_NEQ = store_thm(
  "DOMSUB_FUPDATE_NEQ",
  ``!fm k1 k2 v. ~(k1 = k2) ==> (fm |+ (k1, v) \\ k2 = fm \\ k2 |+ (k1, v))``,
  SRW_TAC [][GSYM fmap_EQ_THM, fmap_domsub,
             pred_setTheory.EXTENSION, DRESTRICT_DEF,
             FAPPLY_FUPDATE_THM] THEN PROVE_TAC []);

val DOMSUB_FUPDATE_THM = store_thm(
  "DOMSUB_FUPDATE_THM",
  ``!fm k1 k2 v. fm |+ (k1,v) \\ k2 = if k1 = k2 then fm \\ k2
                                      else (fm \\ k2) |+ (k1, v)``,
  SRW_TAC [][GSYM fmap_EQ_THM, fmap_domsub,
             pred_setTheory.EXTENSION, DRESTRICT_DEF,
             FAPPLY_FUPDATE_THM] THEN PROVE_TAC []);

val FDOM_DOMSUB = store_thm(
  "FDOM_DOMSUB",
  ``!fm k. FDOM (fm \\ k) = FDOM fm DELETE k``,
  SRW_TAC [][fmap_domsub, FDOM_DRESTRICT, pred_setTheory.EXTENSION]);

val DOMSUB_FAPPLY = store_thm(
  "DOMSUB_FAPPLY",
  ``!fm k. (fm \\ k) ' k = FEMPTY ' k``,
  SRW_TAC [][fmap_domsub, DRESTRICT_DEF]);

val DOMSUB_FAPPLY_NEQ = store_thm(
  "DOMSUB_FAPPLY_NEQ",
  ``!fm k1 k2. ~(k1 = k2) ==> ((fm \\ k1) ' k2 = fm ' k2)``,
  SRW_TAC [][fmap_domsub, DRESTRICT_DEF, NOT_FDOM_FAPPLY_FEMPTY]);

val DOMSUB_FAPPLY_THM = store_thm(
  "DOMSUB_FAPPLY_THM",
  ``!fm k1 k2. (fm \\ k1) ' k2 = if k1 = k2 then FEMPTY ' k2 else fm ' k2``,
  SRW_TAC [] [DOMSUB_FAPPLY, DOMSUB_FAPPLY_NEQ]);

val FRANGE_FUPDATE_DOMSUB = store_thm(
  "FRANGE_FUPDATE_DOMSUB",
  ``!fm k v. FRANGE (fm |+ (k,v)) = v INSERT FRANGE (fm \\ k)``,
  SRW_TAC [][FRANGE_FUPDATE, fmap_domsub]);

val _ = export_rewrites ["DOMSUB_FEMPTY", "DOMSUB_FUPDATE", "FDOM_DOMSUB",
                         "DOMSUB_FAPPLY", "FRANGE_FUPDATE_DOMSUB"]

val o_f_DOMSUB = store_thm(
  "o_f_DOMSUB",
  ``(g o_f fm) \\ k = g o_f (fm \\ k)``,
  SRW_TAC [][GSYM fmap_EQ_THM, DOMSUB_FAPPLY_THM, o_f_FAPPLY]);
val _ = export_rewrites ["o_f_DOMSUB"]

val DOMSUB_IDEM = store_thm(
  "DOMSUB_IDEM",
  ``(fm \\ k) \\ k = fm \\ k``,
  SRW_TAC [][GSYM fmap_EQ_THM, DOMSUB_FAPPLY_THM]);
val _ = export_rewrites ["DOMSUB_IDEM"]

val o_f_FUPDATE = store_thm(
  "o_f_FUPDATE",
  ``f o_f (fm |+ (k,v)) = (f o_f (fm \\ k)) |+ (k, f v)``,
  SRW_TAC [][GSYM fmap_EQ_THM]
  THENL [
    SRW_TAC [][pred_setTheory.EXTENSION] THEN PROVE_TAC [],
    SRW_TAC [][GSYM fmap_EQ_THM, o_f_FAPPLY],
    Cases_on `x = k` THEN
    SRW_TAC [][GSYM fmap_EQ_THM, o_f_FAPPLY, NOT_EQ_FAPPLY,
               DOMSUB_FAPPLY_NEQ]
  ]);
val _ = BasicProvers.export_rewrites ["o_f_FUPDATE"]

val DOMSUB_NOT_IN_DOM = store_thm(
  "DOMSUB_NOT_IN_DOM",
  ``~(k IN FDOM fm) ==> (fm \\ k = fm)``,
  SRW_TAC [][GSYM fmap_EQ_THM, DOMSUB_FAPPLY_THM,
             EXTENSION] THEN PROVE_TAC []);

val fmap_CASES = Q.store_thm
("fmap_CASES",
 `!f:'a |-> 'b. (f = FEMPTY) \/ ?g x y. f = g |+ (x,y)`,
 HO_MATCH_MP_TAC fmap_SIMPLE_INDUCT THEN METIS_TAC []);

val IN_DOMSUB_NOT_EQUAL = Q.prove
(`!f:'a |->'b. !x1 x2. x2 IN FDOM (f \\ x1) ==> ~(x2 = x1)`,
 RW_TAC std_ss [FDOM_DOMSUB,IN_DELETE]);

(*---------------------------------------------------------------------------*)
(* Is there a better statement of this?                                      *)
(*---------------------------------------------------------------------------*)

val SUBMAP_FUPDATE = Q.store_thm
("SUBMAP_FUPDATE",
 `!(f:'a |->'b) g x y.
     (f |+ (x,y)) SUBMAP g =
        x IN FDOM(g) /\ (FAPPLY g x = y) /\ (f\\x) SUBMAP (g\\x)`,
 RW_TAC std_ss [SUBMAP_DEF]
  THEN EQ_TAC
  THEN RW_TAC std_ss [] THENL
  [METIS_TAC [IN_INSERT,FDOM_FUPDATE],
   METIS_TAC [IN_INSERT,FDOM_FUPDATE,FAPPLY_FUPDATE_THM],
   FULL_SIMP_TAC std_ss [FDOM_DOMSUB,IN_DELETE,FDOM_FUPDATE,IN_INSERT],
   FULL_SIMP_TAC std_ss
     [FDOM_DOMSUB,IN_DELETE,IN_INSERT,FAPPLY_FUPDATE_THM,DOMSUB_FAPPLY_THM]
    THEN Q.PAT_ASSUM `$! M` (MP_TAC o Q.SPEC `x'`)
    THEN RW_TAC std_ss [FDOM_FUPDATE,IN_INSERT],
   FULL_SIMP_TAC std_ss [FDOM_DOMSUB,IN_DELETE,FDOM_FUPDATE,IN_INSERT]
    THEN METIS_TAC[],
   FULL_SIMP_TAC std_ss
     [FDOM_DOMSUB,IN_DELETE,IN_INSERT,FAPPLY_FUPDATE_THM,DOMSUB_FAPPLY_THM,
      FDOM_FUPDATE]
    THEN RW_TAC std_ss []]);


(* ----------------------------------------------------------------------
    Iterated updates
   ---------------------------------------------------------------------- *)

val FUPDATE_LIST =
 new_definition
  ("FUPDATE_LIST",
   ``FUPDATE_LIST = FOLDL FUPDATE``);

val _ = overload_on ("|++", ``FUPDATE_LIST``);

val FUPDATE_LIST_THM = store_thm(
  "FUPDATE_LIST_THM",
  ``!f. (f |++ [] = f) /\
        (!h t. f |++ (h::t) = (FUPDATE f h) |++ t)``,
  SRW_TAC [][FUPDATE_LIST]);

val FUPDATE_LIST_APPLY_NOT_MEM = store_thm(
  "FUPDATE_LIST_APPLY_NOT_MEM",
  ``!kvl f k. ~MEM k (MAP FST kvl) ==> ((f |++ kvl) ' k = f ' k)``,
  Induct THEN SRW_TAC [][FUPDATE_LIST_THM] THEN
  Cases_on `h` THEN FULL_SIMP_TAC (srw_ss()) [FAPPLY_FUPDATE_THM]);

(* ----------------------------------------------------------------------
    More theorems
   ---------------------------------------------------------------------- *)

val FAPPLY_FUPD_EQ = prove(
  ``!fmap k1 v1 k2 v2.
       ((fmap |+ (k1, v1)) ' k2 = v2) =
       (k1 = k2) /\ (v1 = v2) \/ ~(k1 = k2) /\ (fmap ' k2 = v2)``,
  SRW_TAC [][FAPPLY_FUPDATE_THM, EQ_IMP_THM]);


(* (pseudo) injectivity results about fupdate *)

val FUPD11_SAME_KEY_AND_BASE = store_thm(
  "FUPD11_SAME_KEY_AND_BASE",
  ``!f k v1 v2. (f |+ (k, v1) = f |+ (k, v2)) = (v1 = v2)``,
  SRW_TAC [][GSYM fmap_EQ_THM, FDOM_FUPDATE, DISJ_IMP_THM,
             FAPPLY_FUPDATE_THM, FORALL_AND_THM, EQ_IMP_THM]);

val FUPD11_SAME_NEW_KEY = store_thm(
  "FUPD11_SAME_NEW_KEY",
  ``!f1 f2 k v1 v2.
         ~(k IN FDOM f1) /\ ~(k IN FDOM f2) ==>
         ((f1 |+ (k, v1) = f2 |+ (k, v2)) = (f1 = f2) /\ (v1 = v2))``,
  SRW_TAC [][GSYM fmap_EQ_THM, FDOM_FUPDATE, DISJ_IMP_THM,
             FAPPLY_FUPDATE_THM, FORALL_AND_THM, EQ_IMP_THM, EXTENSION] THEN
  PROVE_TAC []);

val SAME_KEY_UPDATES_DIFFER = store_thm(
  "SAME_KEY_UPDATES_DIFFER",
  ``!f1 f2 k v1 v2. ~(v1 = v2) ==> ~(f1 |+ (k, v1) = f2 |+ (k, v2))``,
  SRW_TAC [][GSYM fmap_EQ_THM, FDOM_FUPDATE, RIGHT_AND_OVER_OR,
             EXISTS_OR_THM]);

val FUPD11_SAME_BASE = store_thm(
  "FUPD11_SAME_BASE",
  ``!f k1 v1 k2 v2.
        (f |+ (k1, v1) = f |+ (k2, v2)) =
        (k1 = k2) /\ (v1 = v2) \/
        ~(k1 = k2) /\ k1 IN FDOM f /\ k2 IN FDOM f /\
        (f |+ (k1, v1) = f) /\ (f |+ (k2, v2) = f)``,
  SRW_TAC [][FDOM_FEMPTY, FDOM_FUPDATE, GSYM fmap_EQ_THM,
             DISJ_IMP_THM, FORALL_AND_THM, FAPPLY_FUPDATE_THM,
             EXTENSION] THEN PROVE_TAC[]);

val FUPD_SAME_KEY_UNWIND = store_thm(
  "FUPD_SAME_KEY_UNWIND",
  ``!f1 f2 k v1 v2.
       (f1 |+ (k, v1) = f2 |+ (k, v2)) ==>
       (v1 = v2) /\ (!v. f1 |+ (k, v) = f2 |+ (k, v))``,
  SRW_TAC [][FDOM_FEMPTY, FDOM_FUPDATE, GSYM fmap_EQ_THM,
             DISJ_IMP_THM, FORALL_AND_THM, FAPPLY_FUPDATE_THM,
             EXTENSION] THEN PROVE_TAC[]);

val FUPD11_SAME_UPDATE = store_thm(
  "FUPD11_SAME_UPDATE",
  ``!f1 f2 k v. (f1 |+ (k,v) = f2 |+ (k,v)) =
                (DRESTRICT f1 (COMPL {k}) = DRESTRICT f2 (COMPL {k}))``,
  SRW_TAC [][GSYM fmap_EQ_THM, EXTENSION, DRESTRICT_DEF, FDOM_FUPDATE,
             FAPPLY_FUPDATE_THM] THEN PROVE_TAC []);

val _ = temp_overload_on ("LMEM", ``LIST_TO_SET``)

val LMEM_THM = prove(
  ``(LMEM [] = {}) /\ (LMEM (h::t) = h INSERT LMEM t)``,
  SRW_TAC [][EXTENSION]);
val _ = augment_srw_ss [rewrites [LMEM_THM]]

val FDOM_FUPDATE_LIST = store_thm(
  "FDOM_FUPDATE_LIST",
  ``!kvl fm. FDOM (fm |++ kvl) =
             FDOM fm UNION LMEM (MAP FST kvl)``,
  Induct THEN
  ASM_SIMP_TAC (srw_ss()) [FUPDATE_LIST_THM,
                           FDOM_FUPDATE, pairTheory.FORALL_PROD,
                           EXTENSION] THEN PROVE_TAC []);

val FUPDATE_LIST_SAME_UPDATE = store_thm(
  "FUPDATE_LIST_SAME_UPDATE",
  ``!kvl f1 f2. (f1 |++ kvl = f2 |++ kvl) =
                (DRESTRICT f1 (COMPL (LMEM (MAP FST kvl))) =
                 DRESTRICT f2 (COMPL (LMEM (MAP FST kvl))))``,
  Induct THENL [
    SRW_TAC [][GSYM fmap_EQ_THM, FUPDATE_LIST_THM, DRESTRICT_DEF] THEN
    PROVE_TAC [],
    ASM_SIMP_TAC (srw_ss()) [FUPDATE_LIST_THM, pairTheory.FORALL_PROD] THEN
    POP_ASSUM (K ALL_TAC) THEN
    SRW_TAC [][GSYM fmap_EQ_THM, FUPDATE_LIST_THM, DRESTRICT_DEF,
               FDOM_FUPDATE, FDOM_FUPDATE_LIST, EXTENSION,
               FAPPLY_FUPDATE_THM] THEN
    EQ_TAC THEN REPEAT STRIP_TAC THEN REPEAT COND_CASES_TAC THEN
    SRW_TAC [][] THEN PROVE_TAC []
  ]);

val FUPDATE_LIST_SAME_KEYS_UNWIND = store_thm(
  "FUPDATE_LIST_SAME_KEYS_UNWIND",
  ``!f1 f2 kvl1 kvl2.
       (f1 |++ kvl1 = f2 |++ kvl2) /\
       (MAP FST kvl1 = MAP FST kvl2) /\ ALL_DISTINCT (MAP FST kvl1) ==>
       (kvl1 = kvl2) /\
       !kvl. (MAP FST kvl = MAP FST kvl1) ==>
             (f1 |++ kvl = f2 |++ kvl)``,
  CONV_TAC (BINDER_CONV SWAP_VARS_CONV THENC SWAP_VARS_CONV) THEN
  Induct THEN ASM_SIMP_TAC (srw_ss()) [FUPDATE_LIST_THM] THEN
  REPEAT GEN_TAC THEN
  `?k v. h = (k,v)` by PROVE_TAC [pair_CASES] THEN
  POP_ASSUM SUBST_ALL_TAC THEN SIMP_TAC (srw_ss()) [] THEN
  `(kvl2 = []) \/ ?k2 v2 t2. kvl2 = (k2,v2) :: t2` by
       PROVE_TAC [pair_CASES, listTheory.list_CASES] THEN
  POP_ASSUM SUBST_ALL_TAC THEN SIMP_TAC (srw_ss()) [] THEN
  SIMP_TAC (srw_ss()) [FUPDATE_LIST_THM] THEN STRIP_TAC THEN
  `kvl1 = t2` by PROVE_TAC [] THEN POP_ASSUM SUBST_ALL_TAC THEN
  `v = v2` by (FIRST_X_ASSUM (MP_TAC o C Q.AP_THM `k` o Q.AP_TERM `(')`) THEN
               SRW_TAC [][FUPDATE_LIST_APPLY_NOT_MEM]) THEN
  SRW_TAC [][] THEN
  `(kvl = []) \/ (?k' v' t. kvl = (k',v') :: t)` by
     PROVE_TAC [pair_CASES, listTheory.list_CASES] THEN
  POP_ASSUM SUBST_ALL_TAC THEN FULL_SIMP_TAC (srw_ss()) [] THEN
  Q.PAT_ASSUM `fm : 'a |-> 'b = fm1` MP_TAC THEN
  SIMP_TAC (srw_ss()) [GSYM FUPDATE_LIST_THM] THEN
  ASM_SIMP_TAC (srw_ss()) [FUPDATE_LIST_SAME_UPDATE]);

val lemma = prove(
  ``!kvl k fm. MEM k (MAP FST kvl) ==>
               MEM (k, (fm |++ kvl) ' k) kvl``,
  Induct THEN
  ASM_SIMP_TAC (srw_ss()) [pairTheory.FORALL_PROD, FUPDATE_LIST_THM,
                           DISJ_IMP_THM, FORALL_AND_THM] THEN
  REPEAT STRIP_TAC THEN
  Cases_on `MEM p_1 (MAP FST kvl)` THEN
  SRW_TAC [][FUPDATE_LIST_APPLY_NOT_MEM]);

val FM_CONCRETE_EQ_ENUMERATE_CASES = store_thm(
  "FMEQ_ENUMERATE_CASES",
  ``!f1 kvl p. (f1 |+ p = FEMPTY |++ kvl) ==> MEM p kvl``,
  SIMP_TAC (srw_ss()) [pairTheory.FORALL_PROD, GSYM fmap_EQ_THM,
                       FDOM_FUPDATE, FDOM_FUPDATE_LIST, DISJ_IMP_THM,
                       FORALL_AND_THM, FDOM_FEMPTY] THEN
  REPEAT STRIP_TAC THEN
  FULL_SIMP_TAC (srw_ss()) [pred_setTheory.EXTENSION] THEN
  PROVE_TAC [lemma]);

val FMEQ_SINGLE_SIMPLE_ELIM = store_thm(
  "FMEQ_SINGLE_SIMPLE_ELIM",
  ``!P k v ck cv nv. (?fm. (fm |+ (k, v) = FEMPTY |+ (ck, cv)) /\
                           P (fm |+ (k, nv))) =
                     (k = ck) /\ (v = cv) /\ P (FEMPTY |+ (ck, nv))``,
  REPEAT GEN_TAC THEN EQ_TAC THEN STRIP_TAC THENL [
    `FEMPTY |+ (ck, cv) = FEMPTY |++ [(ck,cv)]`
       by SRW_TAC [][FUPDATE_LIST_THM] THEN
    `MEM (k,v) [(ck, cv)]` by PROVE_TAC [FM_CONCRETE_EQ_ENUMERATE_CASES] THEN
    FULL_SIMP_TAC (srw_ss()) [FUPDATE_LIST_THM] THEN
    PROVE_TAC [FUPD_SAME_KEY_UNWIND],
    Q.EXISTS_TAC `FEMPTY` THEN SRW_TAC [][]
  ]);

val FMEQ_SINGLE_SIMPLE_DISJ_ELIM = store_thm(
  "FMEQ_SINGLE_SIMPLE_DISJ_ELIM",
  ``!fm k v ck cv.
       (fm |+ (k,v) = FEMPTY |+ (ck, cv)) =
       (k = ck) /\ (v = cv) /\
       ((fm = FEMPTY) \/ (?v'. fm = FEMPTY |+ (k, v')))``,
  REPEAT GEN_TAC THEN EQ_TAC THEN
  SIMP_TAC (srw_ss()) [DISJ_IMP_THM, LEFT_AND_OVER_OR,
                       GSYM RIGHT_EXISTS_AND_THM,
                       GSYM LEFT_FORALL_IMP_THM] THEN
  SIMP_TAC (srw_ss() ++ boolSimps.CONJ_ss)
           [GSYM fmap_EQ_THM, DISJ_IMP_THM, FORALL_AND_THM] THEN
  SIMP_TAC (srw_ss()) [EXTENSION] THEN
  PROVE_TAC [FAPPLY_FUPDATE]);

val FAPPLY_FEMPTY = Q.prove
(`FAPPLY (FEMPTY:('a,'b)fmap) x :'b =
  FAIL FAPPLY ^(mk_var("empty map",bool)) FEMPTY x`,
 REWRITE_TAC [combinTheory.FAIL_THM]);

val DRESTRICT_PRED_THM =
  SIMP_RULE std_ss [boolTheory.IN_DEF]
   (CONJ DRESTRICT_FEMPTY DRESTRICT_FUPDATE);

val DRESTRICT_PRED_THM =
  SIMP_RULE std_ss [boolTheory.IN_DEF]
   (CONJ DRESTRICT_FEMPTY DRESTRICT_FUPDATE);

(*---------------------------------------------------------------------------*)
(* val th = |- !x. COMPL {x} = (\a. ~(a = x))                                *)
(*---------------------------------------------------------------------------*)

val th = GEN_ALL
             (CONV_RULE (DEPTH_CONV ETA_CONV)
               (ABS (Term `a:'a`)
                 (SIMP_RULE std_ss [IN_SING,IN_DEF]
                   (Q.SPEC `{x}` (Q.SPEC `a` IN_COMPL)))));

val RRESTRICT_PRED_THM = Q.prove
(`(!P. RRESTRICT (FEMPTY:'a|->'b) P = (FEMPTY:'a|->'b)) /\
  (!(f:'a|->'b) P x y.
       RRESTRICT (f |+ (x,y)) P =
        if P y then RRESTRICT f P |+ (x,y)
          else RRESTRICT (DRESTRICT f (\a. ~(a = x))) P)`,
 REWRITE_TAC [RRESTRICT_FEMPTY]
  THEN METIS_TAC [REWRITE_RULE [th] RRESTRICT_FUPDATE, IN_DEF]);

val FRANGE_EQNS = Q.prove
(`(FRANGE (FEMPTY:'a|->'b) = ({}:'b set)) /\
  (!(f:'a |-> 'b) (x:'a) (y:'b).
         FRANGE (f |+ (x,y)) = y INSERT FRANGE (DRESTRICT f (\a. ~(a = x))))`,
 METIS_TAC [REWRITE_RULE [th] FRANGE_FUPDATE, FRANGE_FEMPTY]);

val o_f_EQNS = Q.prove
(`(f          o_f (FEMPTY:'a|->'b) = (FEMPTY:'a|->'c)) /\
  ((f:'b->'c) o_f ((fm:'a|->'b) |+ (k,v)) = (f o_f fm \\ k) |+ (k,f v))`,
 METIS_TAC [o_f_FEMPTY, o_f_FUPDATE]);

val T_INTRO = PURE_ONCE_REWRITE_RULE [PROVE[] (Term `x = (x = T)`)];

val _ =
 let open EmitML combinSyntax ParseDatatype arithmeticTheory
  in try emitML (!Globals.emitMLDir)
   ("fmap",
    ABSDATATYPE (["'a","'b"], `fmap = FEMPTY | FUPDATE of fmap => 'a#'b`)
    :: OPEN ["num", "list", "set", "option"]
    :: MLSIG "type num = numML.num"
    :: MLSIG "type 'a set = 'a setML.set"
    :: MLSIG "val FEMPTY   : ('a,'b) fmap"
    :: MLSIG "val FUPDATE  : ('a,'b) fmap * ('a * 'b) -> ('a,'b)fmap"
    :: MLSIG "val FDOM     : ('a,'b) fmap -> 'a set"
    ::
    [DEFN_NOSIG (CONJ FDOM_FEMPTY FDOM_FUPDATE),
     DEFN ((CONJ FAPPLY_FEMPTY FAPPLY_FUPDATE_THM)),
     DEFN (FCARD_DEF),
     DEFN (FLOOKUP_DEF),
     DEFN (FUPDATE_LIST),
     DEFN ((CONJ FUNION_FEMPTY_1
                (CONJ FUNION_FEMPTY_2 FUNION_FUPDATE_1))),
     DEFN ((CONJ DOMSUB_FEMPTY DOMSUB_FUPDATE_THM)),
     DEFN ((CONJ (T_INTRO (SPEC_ALL SUBMAP_FEMPTY)) SUBMAP_FUPDATE)),
     DEFN (DRESTRICT_PRED_THM),
     DEFN (RRESTRICT_PRED_THM),
     MLSIG "val FRANGE : (''a,'b)fmap -> 'b set",
     DEFN_NOSIG (FRANGE_EQNS),
     DEFN (o_f_EQNS),
     DEFN ((CONJ (T_INTRO (SPEC_ALL FEVERY_FEMPTY))
                 (REWRITE_RULE [th] FEVERY_FUPDATE)))
  ])
end;

(* ----------------------------------------------------------------------
    to close...
   ---------------------------------------------------------------------- *)


val _ = export_theory();

end
