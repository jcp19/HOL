signature tacticToe =
sig

  include Abbrev

  val set_timeout : real -> unit
  val ttt : tactic
  val tactictoe : term -> thm

  (* recorded data from ancestries of the current theory *)
  val clean_ttt_tacdata_cache : unit -> unit

  (* evaluation *)
  type lbl = (string * real * goal * goal list)
  type fea = int list
  type thmdata =
    (int, real) Redblackmap.dict *
    (string, int list) Redblackmap.dict
  type tacdata =
    {
    tacfea : (lbl,fea) Redblackmap.dict,
    tacfea_cthy : (lbl,fea) Redblackmap.dict,
    taccov : (string, int) Redblackmap.dict,
    tacdep : (goal, lbl list) Redblackmap.dict
    }
  val ttt_eval : thmdata * tacdata -> goal -> unit

end
