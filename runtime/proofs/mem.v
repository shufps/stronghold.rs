(* Copyright 2020 IOTA Stiftung *)
(* SPDX-License-Identifier: Apache-2.0 *)

Require Import PeanoNat.
Require Import Psatz.

(* x = mmap N                            *)
(* |   | p |     n    | q | guard |      *)
(* P   P   A              P              *)
(*                                       *)
(* Question: how can we minimize q?      *)

Definition pad x N :=
  match x mod N with 0 => 0 | r => N - r end.

Lemma pad_le {A x y}: A <> 0 ->
  0 < y mod A <= x mod A -> pad x A <= pad y A.
Proof.
  intros.
  unfold pad.
  case_eq (x mod A); case_eq (y mod A); intros; lia.
Qed.

Lemma pad_bound a b: b <> 0 -> pad a b < b.
Proof.
  intro Bnz.
  unfold pad.
  case_eq (a mod b); lia.
Qed.

Lemma pad_add_l a b c: c <> 0 -> a mod c = 0 -> pad (a + b) c = pad b c.
Proof.
  intros Cnz AC.
  unfold pad.
  now rewrite <- (Nat.add_mod_idemp_l _ _ _ Cnz), AC.
Qed.

Lemma pad_add_r a b c: c <> 0 -> b mod c = 0 -> pad (a + b) c = pad a c.
Proof.
  intros Cnz AC.
  rewrite Nat.add_comm.
  now apply pad_add_l.
Qed.

Lemma pad_0 {A}: A <> 0 -> pad 0 A = 0.
Proof.
  intro Anz.
  unfold pad.
  now rewrite (Nat.mod_0_l _ Anz).
Qed.

Definition pad_minimizer a b c :=
  if b mod c =? 0 then 0 else
  if b mod c mod a =? 0
  then c / a - b mod c / a
  else c / a - 1 - b mod c / a.

Lemma pad_minimizer_bound a b c:
  a <> 0 -> pad_minimizer a b c <= c / a.
Proof.
  intros Anz.
  unfold pad_minimizer.
  case (b mod c =? 0); case (b mod c mod a =? 0); lia.
Qed.

Lemma pad_minimizer_mul_bound a b c:
  a <> 0 -> pad_minimizer a b c * a <= pad b c.
Proof.
  intros Anz.
  unfold pad_minimizer, pad.
  case_eq (b mod c =? 0); intro bc; [lia|].

  case_eq (b mod c); [intro H; exfalso; now refine (proj1 (Nat.eqb_neq _ _) bc _)|].
  intros n N.
  rewrite <- N.
  clear n N.

  case_eq (b mod c mod a =? 0).
  - intro bca.
    rewrite Nat.mul_sub_distr_r.
    refine (Nat.le_trans _ (c - b mod c / a * a) _ _ _).
    + refine (Nat.sub_le_mono_r _ _ _ _).
      now rewrite Nat.mul_comm, (Nat.mul_div_le c _ Anz).
    + refine (Nat.sub_le_mono_l _ _ _ _).
      destruct (proj1 (Nat.mod_divides _ _ Anz) (proj1 (Nat.eqb_eq _ _) bca)) as [j J].
      now rewrite J, Nat.mul_comm, (Nat.div_mul _ _ Anz).
  - intro bca.
    rewrite <- Nat.sub_add_distr.
    rewrite Nat.mul_sub_distr_r.
    refine (Nat.le_trans _ (c - (1 + b mod c / a) * a) _ _ _).
    + refine (Nat.sub_le_mono_r _ _ _ _).
      now rewrite Nat.mul_comm, (Nat.mul_div_le c _ Anz).
    + refine (Nat.sub_le_mono_l _ _ _ _).
      rewrite Nat.mul_add_distr_r.
      rewrite Nat.add_comm, Nat.mul_1_l.

      rewrite (Nat.div_mod (b mod c) a Anz) at 1.
      refine (Nat.add_le_mono _ _ _ _ _ _); [lia|].
      refine (Nat.lt_le_incl _ _ _).
      now apply Nat.mod_upper_bound.
Qed.

Lemma pad_add_small x y A: A <> 0 -> x <= pad y A -> x + pad (x + y) A = pad y A.
Proof.
  intros Anz L.
  unfold pad in *.
  case_eq (y mod A).
  - intro z.
    rewrite z in L.
    rewrite (proj1 (Nat.le_0_r _) L).
    repeat rewrite Nat.add_0_l.
    now rewrite z.
  - intros n N.
    rewrite N, <- N in L.
    case (Compare_dec.le_lt_eq_dec _ _ L).
    + intro L'.
      pose (K := proj1 (Nat.add_lt_mono_r x (A - y mod A) (y mod A)) L').
      rewrite (Nat.sub_add _ _ (Nat.lt_le_incl _ _ (Nat.mod_upper_bound y _ Anz))) in K.
      rewrite <- (Nat.add_mod_idemp_r _ _ _ Anz), (Nat.mod_small _ _ K).
      case_eq (x + y mod A); lia.
    + intro L'.
      rewrite L'.
      rewrite <- (Nat.add_mod_idemp_r _ _ _ Anz).
      rewrite (Nat.sub_add (y mod A) A (Nat.lt_le_incl _ _ (Nat.mod_upper_bound y _ Anz))).
      rewrite (Nat.mod_same _ Anz).
      lia.
Qed.

Lemma pad_min a b c: c mod a = 0 ->
  let i := pad_minimizer a b c in
  forall j, pad (a * i + b) c <= pad (a * j + b) c.
Proof.
  intros CA m.
  case (Nat.eq_dec c 0); [intro z; now rewrite z|]; intro Cnz.
  case (Nat.eq_dec a 0); [intro z; now rewrite z|]; intro Anz.
  destruct (proj1 (Nat.mod_divides _ a Anz) CA) as [j J].

  case (Nat.eq_dec (b mod c) 0).
  - intros z i.
    rewrite (pad_add_r _ _ _ Cnz z).
    unfold m, pad_minimizer.
    rewrite (proj2 (Nat.eqb_eq _ _) z).
    rewrite Nat.mul_0_r.
    rewrite (pad_0 Cnz).
    apply Nat.le_0_l.
  - intros nz i.
    case (Nat.eq_dec (b mod c mod a) 0).
    + intros R.
      destruct (proj1 (Nat.mod_divides _ a Anz) R) as [k K].
      assert (m = j - k) as M. {
        unfold m, pad_minimizer.
        rewrite (proj2 (Nat.eqb_neq _ _) nz).
        rewrite (proj2 (Nat.eqb_eq _ _) R), K, J.
        now repeat rewrite Nat.mul_comm, (Nat.div_mul _ _ Anz).
      }
      rewrite M.

      unfold pad.
      rewrite <- (Nat.add_mod_idemp_r _ b c Cnz), K.
      rewrite <- Nat.mul_add_distr_l.

      assert (k <= j) as KJ. {
        refine (Nat.lt_le_incl _ _ _).
        pose (L := Nat.mod_upper_bound b c Cnz).
        rewrite K, J in L.
        exact (proj2 (Nat.mul_lt_mono_pos_l a k j (proj1 (Nat.neq_0_lt_0 _) Anz)) L).
      }
      rewrite (Nat.sub_add k j KJ).

      rewrite <- J, (Nat.mod_same _ Cnz).
      apply Nat.le_0_l.
    + intro R.
      destruct j; [exfalso; rewrite Nat.mul_0_r in J; now apply Cnz|].

      pose (k := b mod c / a).
      pose (r := b mod c mod a).
      assert (m = j - k) as M. {
        unfold m, pad_minimizer.
        rewrite (proj2 (Nat.eqb_neq _ _) nz).
        rewrite (proj2 (Nat.eqb_neq _ _) R).
        rewrite J.
        rewrite Nat.mul_comm at 1.
        now rewrite (Nat.div_mul _ _ Anz), Nat.sub_1_r, Nat.pred_succ, <- J.
      }
      rewrite M.

      refine (pad_le Cnz _).
      repeat rewrite <- (Nat.add_mod_idemp_r _ b c Cnz).
      rewrite (Nat.div_mod (b mod c) a Anz).
      fold k. fold r.
      repeat rewrite Nat.add_assoc, <- Nat.mul_add_distr_l.

      assert (k <= j) as KJ. {
        unfold k.
        refine (proj1 (Nat.lt_succ_r _ _) _).
        refine (Nat.div_lt_upper_bound _ _ _ Anz _).
        rewrite <- J.
        exact (Nat.mod_upper_bound _ _ Cnz).
      }
      rewrite (Nat.sub_add _ _ KJ).

      assert (a * j + r < c) as AJRC. {
        rewrite J.
        rewrite Nat.mul_succ_r.
        refine (proj1 (Nat.add_lt_mono_l _ _ _) _).
        apply (Nat.mod_upper_bound (b mod c) _ Anz).
      }
      rewrite (Nat.mod_small _ _ AJRC).

      rewrite <- (Nat.add_mod_idemp_l _ _ _ Cnz), J.
      rewrite (Nat.mul_mod_distr_l _ _ _ (Nat.neq_succ_0 _) Anz).

      assert (a * ((i + k) mod S j) + r < a * S j) as l. {
        rewrite Nat.mul_succ_r.
        refine (Nat.add_le_lt_mono _ _ _ _ _ _).
        - refine (proj1 (Nat.mul_le_mono_pos_l _ _ _ (proj1 (Nat.neq_0_lt_0 _) Anz)) _).
          refine (proj2 (Nat.succ_le_mono _ _) _).
          exact (Nat.mod_upper_bound _ _ (Nat.neq_succ_0 _)).
        - now apply Nat.mod_upper_bound.
      }
      rewrite (Nat.mod_small _ _ l).

      split.
      ++ rewrite <- (Nat.add_0_l 0).
         refine (Nat.add_le_lt_mono _ _ _ _ (Nat.le_0_l _) _).
         now refine (proj1 (Nat.neq_0_lt_0 _) _).
      ++ refine (proj1 (Nat.add_le_mono_r _ _ _) _).
         refine (proj1 (Nat.mul_le_mono_pos_l _ _ _ (proj1 (Nat.neq_0_lt_0 _) Anz)) _).
         refine (proj1 (Nat.lt_succ_r _ _) _).
         exact (Nat.mod_upper_bound _ _ (Nat.neq_succ_0 _)).
Qed.

Definition aligned x N := N <> 0 /\ pad x N = 0.

Lemma unaligned x: aligned x 1.
Proof.
  now split.
Qed.

Lemma aligned_mod {x N}: aligned x N -> x mod N = 0.
Proof.
  intros [Nz P].
  unfold pad in P.
  case_eq (x mod N); [auto|].
  intros m M.
  rewrite M, <- M in P.

  assert (Q: 0 < N - x mod N). {
    unfold lt.
    rewrite <- (Nat.sub_diag (x mod N)), <- Nat.sub_succ_l by auto.
    refine (Nat.sub_le_mono_r _ _ _ _).
    refine (proj2 (Nat.mod_bound_pos _ _ (le_0_n _) _)).
    now apply Nat.neq_0_lt_0.
  }

  rewrite P in Q.
  discriminate (proj1 (Nat.le_0_r 1) Q).
Qed.

Lemma align_weaken A B x: aligned A B -> aligned x A -> aligned x B.
Proof.
  intros AB XA.
  destruct (proj1 (Nat.mod_divides _ _ (proj1 AB)) (aligned_mod AB)) as [p P].
  rewrite P in XA.
  destruct (proj1 (Nat.mod_divides _ _ (proj1 XA)) (aligned_mod XA)) as [q Q].
  rewrite Q.
  refine (conj (proj1 AB) _).
  unfold pad.
  rewrite <- Nat.mul_assoc, Nat.mul_comm.
  now rewrite (Nat.mod_mul (p * q) B (proj1 AB)).
Qed.

Axiom accessible : nat -> Prop.
Definition accessible_range b n := forall m, m < n -> accessible (b + m).
Definition mmap P := forall n, { p | aligned p P /\ accessible_range p n }.

Record Allocation (n A: nat) := mkAllocation {
  data: nat;
  data_alignment: aligned data A;
  data_accessible: accessible_range data n;
}.

Lemma naive_allocator {P} (M: mmap P):
  forall n {A}, aligned P A -> Allocation n A.
Proof.
  intros n A PA.
  destruct (M n) as [x [XP XAcc]].
  pose (Anz := proj1 PA).
  refine (mkAllocation _ _ x _ _); unfold aligned, pad.
  + now rewrite (aligned_mod (align_weaken _ _ _ PA XP)).
  + exact XAcc.
Qed.

Record GuardedAllocation (n A P: nat) := mkGuardedAllocation {
  allocation: Allocation n A;

  mmapper: mmap P;
  mmapped_size: nat;
  base := proj1_sig (mmapper mmapped_size);

  data' := data _ _ allocation;
  offset: nat;
  pad_pre: nat;
  data_offset: data' = base + (1 + offset) * P + pad_pre;
  post_guard: (1 + offset) * P + pad_pre + n + pad (data' + n) P + P <= mmapped_size;
}.

Lemma naive_guarded_allocator {P} (M: mmap P):
  forall n {A}, aligned P A -> GuardedAllocation n A P.
Proof.
  intros n A PA.
  pose (N := P + n + pad n P + P).
  case_eq (M N); intros x [XP XAcc] Mx.
  pose (Anz := proj1 PA).
  pose (Pnz := proj1 XP).

  simple refine (mkGuardedAllocation _ _ _ (mkAllocation _ _ (x + P) _ _) M N 0 0 _ _).
  - unfold aligned.
    now rewrite (pad_add_l _ _ _ Anz (aligned_mod (align_weaken _ _ _ PA XP))).
  - intros i I.
    rewrite <- Nat.add_assoc.
    refine (XAcc _ _).
    lia.
  - rewrite Mx. simpl. lia.
  - simpl.
    unfold N.
    repeat rewrite pad_add_l; try lia.
    rewrite <- (Nat.add_mod_idemp_l _ _ _ Pnz).
    rewrite (aligned_mod XP), Nat.add_0_l.
    now rewrite Nat.mod_same.
Qed.

Record OptimalAllocation (n A P: nat) := mkOptimalAllocation {
  guarded_allocation: GuardedAllocation n A P;
  post_padding_min: forall a': GuardedAllocation n A P,
    pad (data' _ _ _ guarded_allocation + n) P <= pad (data' _ _ _ a' + n) P;
}.

Lemma optimal_allocator_page_aligned {P} (M: mmap P):
  forall n {A}, aligned P A -> OptimalAllocation n A P.
Proof.
  intros n A PA.

  pose (N := P + n + pad n P + P).
  case_eq (M N). intros x [XP XAcc] Mx.

  pose (Anz := proj1 PA).
  pose (Pnz := proj1 XP).
  pose (XA := aligned_mod (align_weaken _ _ x PA XP)).

  pose (i := pad_minimizer A n P).

  simple refine (mkOptimalAllocation _ _ _ (mkGuardedAllocation _ _ _ (mkAllocation n A (x + P + i * A) _ _) M N 0 (i * A) _ _) _).
  - refine (conj Anz _).
    repeat rewrite <- Nat.add_assoc.
    repeat rewrite pad_add_l; try lia.
    + unfold pad; now rewrite Nat.mod_mul.
    + now apply aligned_mod.
  - intros j J.
    repeat rewrite <- Nat.add_assoc.
    refine (XAcc _ _).
    unfold N.
    repeat rewrite <- Nat.add_assoc.
    refine (proj1 (Nat.add_lt_mono_l _ _ _) _).
    rewrite Nat.add_comm.
    refine (Nat.add_lt_le_mono _ _ _ _ J _).
    rewrite <- Nat.add_0_l at 1.
    refine (Nat.add_le_mono _ _ _ _ (Nat.le_0_l _) _).
    refine (Nat.le_trans (i * A) (P / A * A) P _ _).
    + unfold i; exact (Nat.mul_le_mono_r _ _ A (pad_minimizer_bound A n P Anz)).
    + rewrite Nat.mul_comm; now apply Nat.mul_div_le.
  - rewrite Mx. simpl; lia.
  - simpl.
    unfold N.
    repeat rewrite <- Nat.add_assoc.
    rewrite (pad_add_l _ _ _ Pnz (aligned_mod XP)).
    rewrite (pad_add_l _ _ _ Pnz (Nat.mod_same _ Pnz)).
    refine (proj1 (Nat.add_le_mono_l _ _ _) _).
    repeat rewrite Nat.add_assoc.
    refine (proj1 (Nat.add_le_mono_r _ _ _) _).
    rewrite <- Nat.add_assoc.
    rewrite Nat.add_comm.
    rewrite <- Nat.add_assoc.
    refine (proj1 (Nat.add_le_mono_l _ _ _) _).
    rewrite Nat.add_comm.
    rewrite pad_add_small; [auto|exact Pnz|].
    now apply pad_minimizer_mul_bound.
  - intro a'.
    unfold data'.
    simpl.
    repeat rewrite <- Nat.add_assoc.
    rewrite (pad_add_l _ _ _ Pnz (aligned_mod XP)).
    rewrite (pad_add_l _ _ _ Pnz (Nat.mod_same _ Pnz)).
    destruct (proj1 (Nat.mod_divides _ _ Anz) (aligned_mod (data_alignment _ _ (allocation _ _ _ a')))) as [j J].
    rewrite J, Nat.mul_comm.
    apply (pad_min _ _ _ (aligned_mod PA)).
Qed.

Lemma optimal_allocator_super_page_aligned {P} (M: mmap P):
  forall n {A}, A <> 0 -> aligned A P -> OptimalAllocation n A P.
Proof.
  intros n A Anz AP.
  pose (Pnz := proj1 AP).

  pose (N := A + n + pad n P + P).
  case_eq (M N). intros x [XP XAcc] Mx.

  pose (AP' := Nat.div_mod A P Pnz).
  rewrite (aligned_mod AP), Nat.add_0_r in AP'.
  pose (i := A / P).

  assert (Inz: i <> 0) by lia.

  pose (XP' := Nat.div_mod x P Pnz).
  rewrite (aligned_mod XP), Nat.add_0_r in XP'.
  pose (j := x / P).

  pose (o := i - 1 - j mod i).
  pose (d := x + o * P + P).

  simple refine (mkOptimalAllocation _ _ _ (mkGuardedAllocation _ _ _ (mkAllocation n A d _ _) M N o 0 _ _) _).
  - refine (conj Anz _).
    unfold d, o.
    rewrite XP'.
    fold j.
    rewrite (Nat.mul_comm P j).
    rewrite <- (Nat.mul_1_l P) at 3.
    repeat rewrite <- Nat.mul_add_distr_r.
    unfold pad.
    rewrite (Nat.div_mod j i Inz) at 1.
    rewrite <- Nat.sub_add_distr.
    repeat rewrite <- Nat.add_assoc.
    rewrite Nat.mul_add_distr_r.
    rewrite <- (Nat.add_mod_idemp_l _ _ _ Anz).
    rewrite Nat.mul_comm.
    rewrite Nat.mul_assoc.
    unfold i at 1.
    rewrite <- AP'.
    rewrite Nat.mul_comm at 1.
    rewrite Nat.mod_mul, Nat.add_0_l, Nat.add_comm, <- Nat.add_assoc.
    rewrite Nat.sub_add.
    + rewrite Nat.mul_comm.
      unfold i.
      rewrite <- AP'.
      now rewrite Nat.mod_same.
    + rewrite Nat.add_1_l.
      exact (Nat.mod_upper_bound j i Inz).
    + auto.
  - intros k K.
    unfold d.
    repeat rewrite <- Nat.add_assoc.
    refine (XAcc _ _).
    unfold o, N.
    rewrite (Nat.add_comm P k), Nat.add_assoc.
    refine (proj1 (Nat.add_lt_mono_r _ _ _) _).
    rewrite <- Nat.add_assoc.
    refine (Nat.add_le_lt_mono _ _ _ _ _ _); [|lia].
    rewrite <- Nat.sub_add_distr, Nat.mul_sub_distr_r, Nat.mul_comm.
    unfold i.
    rewrite <- AP'.
    apply Nat.le_sub_l.
  - rewrite Mx. simpl. unfold d. lia.
  - simpl. unfold N, d.
    refine (proj1 (Nat.add_le_mono_r _ _ _) _).
    repeat rewrite <- Nat.add_assoc.
    rewrite (pad_add_l _ _ _ Pnz (aligned_mod XP)).
    rewrite (pad_add_l (o * P) _ _ Pnz (Nat.mod_mul _ _ Pnz)).
    rewrite (pad_add_l _ _ _ Pnz (Nat.mod_same _ Pnz)).
    repeat rewrite Nat.add_assoc.
    repeat refine (proj1 (Nat.add_le_mono_r _ _ _) _).
    rewrite Nat.add_0_r.
    rewrite AP'.
    rewrite <- (Nat.mul_1_l P) at 1.
    rewrite <- Nat.mul_add_distr_r.
    rewrite Nat.mul_comm.
    refine (Nat.mul_le_mono_l _ _ _ _).
    lia.
  - intro a'.
    unfold data', d.
    simpl.
    repeat rewrite pad_add_l; try auto.
    + refine (aligned_mod _).
      refine (align_weaken _ _ _ AP _).
      exact (data_alignment _ _ (allocation _ _ _ a')).
    + rewrite <- (Nat.add_mod_idemp_r _ _ _ Pnz).
      rewrite (Nat.mod_same _ Pnz), Nat.add_0_r.
      rewrite <- (Nat.add_mod_idemp_r _ _ _ Pnz).
      rewrite (Nat.mod_mul _ _ Pnz), Nat.add_0_r.
      now apply aligned_mod.
Qed.
