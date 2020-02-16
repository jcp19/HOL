(* ========================================================================= *)
(* FILE          : mleCombinSynt.sml                                         *)
(* DESCRIPTION   : Specification of term synthesis on combinators            *)
(* AUTHOR        : (c) Thibault Gauthier, Czech Technical University         *)
(* DATE          : 2020                                                      *)
(* ========================================================================= *)

structure mleCombinSynt :> mleCombinSynt =
struct

open HolKernel Abbrev boolLib aiLib smlParallel psMCTS psTermGen
  mlNeuralNetwork mlTreeNeuralNetwork mlTacticData
  mlReinforce mleCombinLib

val ERR = mk_HOL_ERR "mleCombinSynt"
val version = 13
val selfdir = HOLDIR ^ "/examples/AI_tasks"

(* -------------------------------------------------------------------------
   Board
   ------------------------------------------------------------------------- *)

type board = term * term * int
fun string_of_board (a,b,c)= tts a ^ " " ^ tts b ^ " " ^ its c

fun board_compare ((a,b,c),(d,e,f)) =
  (cpl_compare Term.compare Term.compare) ((a,b),(d,e))

fun status_of (tm1,tm2,n) =
  if not (can (find_term (fn x => term_eq x cX)) tm1) then
    let
      val tm1o = fast_lo_cnorm 100 eq_axl_bare (list_mk_cA [tm1,v1,v2,v3])
    in
      if isSome tm1o andalso term_eq (valOf tm1o) tm2 then Win else Lose
    end
  else if n <= 0 then Lose else Undecided

(* -------------------------------------------------------------------------
   Move
   ------------------------------------------------------------------------- *)

type move = term
val movel = [cA,cS,cK]
val move_compare = Term.compare

fun apply_move move (tm1,tm2,n) = 
  let
    val res = list_mk_comb (move, List.tabulate (arity_of move, fn _ => cX))
    val sub = [{redex = cX, residue = res}]
  in
    (subst_occs [[1]] sub tm1, tm2, n-1)
  end

fun available_movel board = 
  (if contain_red (#1 (apply_move cA board)) then [] else [cA]) @ [cS,cK]

fun string_of_move tm = tts tm

(* -------------------------------------------------------------------------
   Game
   ------------------------------------------------------------------------- *)

val game : (board,move) game =
  {
  status_of = status_of,
  apply_move = apply_move,
  available_movel = available_movel,  
  string_of_board = string_of_board,
  string_of_move = string_of_move,
  board_compare = board_compare,
  move_compare = Term.compare,
  movel = movel
  }

(* -------------------------------------------------------------------------
   Parallelization
   ------------------------------------------------------------------------- *)

fun write_boardl file boardl =
  let val (l1,l2,l3) = split_triple boardl in
    export_terml (file ^ "_in") l1;
    export_terml (file ^ "_out") l2; 
    writel (file ^ "_timer") (map its l3)
  end

fun read_boardl file =
  let
    val l1 = import_terml (file ^ "_in")
    val l2 = import_terml (file ^ "_out")
    val l3 = map string_to_int (readl (file ^ "_timer"))
  in
    combine_triple (l1,l2,l3)
  end

val gameio = {write_boardl = write_boardl, read_boardl = read_boardl}

(* -------------------------------------------------------------------------
   Targets
   ------------------------------------------------------------------------- *)

val targetdir = selfdir ^ "/combin_target"

fun create_targetl tml =
  let
    val i = ref 0
    fun f tm = 
      let val tmo = fast_lo_cnorm 100 eq_axl_bare (list_mk_cA [tm,v1,v2,v3])
      in
        if not (isSome tmo) orelse 
           can (find_term (C tmem [cS,cK])) (valOf tmo)
        then NONE
        else (print_endline (its (!i)); incr i; tmo)
      end
    val l1 = map_assoc f tml    
    val l2 = filter (fn x => isSome (snd x)) l1    
    val l3 = map_snd valOf l2
    val l4 = dregroup Term.compare (map swap l3)
    val l5 = map_snd (list_imin o map term_size) (dlist l4)
    val l6 = map (fn (a,b) => (cX,a,2 * b)) l5
    fun compare_third cmp ((_,_,a),(_,_,b)) = cmp (a,b)
  in
    dict_sort (compare_third Int.compare) l6
  end

fun export_targetl name targetl = 
  let val _ = mkDir_err targetdir in 
    write_boardl (targetdir ^ "/" ^ name) targetl
  end

fun import_targetl name = read_boardl (targetdir ^ "/" ^ name)
 
fun mk_targetd l1 =
  let 
    val l2 = number_snd 0 l1
    val l3 = map (fn (x,i) => (x,(i,[]))) l2
  in
    dnew board_compare l3
  end

(* -------------------------------------------------------------------------
   Neural network representation of the board
   ------------------------------------------------------------------------- *)

val head_eval = mk_var ("head_eval", ``:bool -> 'a``)
val head_poli = mk_var ("head_poli", ``:bool -> 'a``)
fun tag_heval x = mk_comb (head_eval,x)
fun tag_hpoli x = mk_comb (head_poli,x)
fun pretob _ (tm1,tm2,_) = 
  [tag_heval (mk_eq (tm1,tm2)), tag_hpoli (mk_eq (tm1,tm2))]

(* -------------------------------------------------------------------------
   Player
   ------------------------------------------------------------------------- *)

val schedule =
  [{ncore = 4, verbose = true, learning_rate = 0.02,
    batch_size = 16, nepoch = 20}]

val dim = 12
fun dim_head_poli n = [dim,n]
val equality = ``$= : 'a -> 'a -> bool``
val tnnparam = map_assoc (dim_std (1,dim)) [equality,cX,v1,v2,v3,cA,cS,cK] @ 
  [(head_eval,[dim,dim,1]),(head_poli,[dim,dim,length movel])]

val dplayer = {pretob = pretob, tnnparam = tnnparam, schedule = schedule}

(* -------------------------------------------------------------------------
   Interface
   ------------------------------------------------------------------------- *)

val rlparam =
  {expname = "mleCombinSynt-" ^ its version, exwindow = 100000,
   ncore = 30, ntarget = 100, nsim = 32000, decay = 1.0}

val rlobj : (board,move) rlobj =
  {rlparam = rlparam, game = game, gameio = gameio, dplayer = dplayer}

val extsearch = mk_extsearch "mleCombinSynt.extsearch" rlobj

(*
load "mleCombinSynt"; open mleCombinSynt;
load "mlReinforce"; open mlReinforce;
load "aiLib"; open aiLib;
load "mleCombinLib"; open mleCombinLib;

val tml = cgen_synt 9; length tml;

val targetl1 = create_targetl tml; length targetl1;
fun cmp (b1,b2) = cpl_compare 
  (compare_third Int.compare) (#board_compare (#game rlobj)) 
  ((b1,b1),(b2,b2));
val targetl2 = dict_sort cmp targetl1;
val stats = dlist (count_dict (dempty Int.compare) 
   (map ((fn x => x div 4 + 1) o #3) targetl2)); 

val _ = export_targetl "sy9" targetl2;
val r = rl_start (rlobj,extsearch) (mk_targetd (import_targetl "sy9"));
val targetl = import_targetl "sy9";
*)

end (* struct *)