; RUN: opt %loadPolly -polly-detect-unprofitable -polly-scops -analyze < %s | FileCheck %s
;
; Verify the scalar x defined in a non-affine subregion is written as it
; escapes the region. In this test the two conditionals inside the region
; are expressed as two PHI nodes with two incoming values each.
;
;    void f(int *A, int b) {
;      for (int i = 0; i < 1024; i++) {
;        int x = 0;
;        if (A[i]) {
;          if (b > i)
;            x = 0;
;          else if (b < 2 * i)
;            x = i;
;          else
;            x = b;
;        }
;        A[i] = x;
;      }
;    }
;
; CHECK: Region: %bb2---%bb21
; CHECK:   Stmt_bb3__TO__bb18
; CHECK:         Domain :=
; CHECK:             { Stmt_bb3__TO__bb18[i0] : i0 >= 0 and i0 <= 1023 };
; CHECK:         Schedule :=
; CHECK:             { Stmt_bb3__TO__bb18[i0] -> [i0, 0] };
; CHECK-NOT:         { Stmt_bb3__TO__bb18[i0] -> MemRef_x_0[] };
; CHECK-NOT:         { Stmt_bb3__TO__bb18[i0] -> MemRef_x_1[] };
; CHECK:         ReadAccess := [Reduction Type: NONE] [Scalar: 0]
; CHECK-NEXT:        { Stmt_bb3__TO__bb18[i0] -> MemRef_A[i0] };
; CHECK-NOT:         { Stmt_bb3__TO__bb18[i0] -> MemRef_x_0[] };
; CHECK-NOT:         { Stmt_bb3__TO__bb18[i0] -> MemRef_x_1[] };
; CHECK:         MustWriteAccess :=  [Reduction Type: NONE] [Scalar: 1]
; CHECK-NEXT:        { Stmt_bb3__TO__bb18[i0] -> MemRef_x_2__phi[] };
; CHECK-NOT:         { Stmt_bb3__TO__bb18[i0] -> MemRef_x_0[] };
; CHECK-NOT:         { Stmt_bb3__TO__bb18[i0] -> MemRef_x_1[] };
; CHECK:         MayWriteAccess := [Reduction Type: NONE] [Scalar: 1]
; CHECK-NEXT:        { Stmt_bb3__TO__bb18[i0] -> MemRef_x_2__phi[] };
; CHECK-NOT:         { Stmt_bb3__TO__bb18[i0] -> MemRef_x_0[] };
; CHECK-NOT:         { Stmt_bb3__TO__bb18[i0] -> MemRef_x_1[] };
; CHECK:   Stmt_bb18
; CHECK:         Domain :=
; CHECK:             { Stmt_bb18[i0] : i0 >= 0 and i0 <= 1023 };
; CHECK:         Schedule :=
; CHECK:             { Stmt_bb18[i0] -> [i0, 1] };
; CHECK:         ReadAccess := [Reduction Type: NONE] [Scalar: 1]
; CHECK:             { Stmt_bb18[i0] -> MemRef_x_2__phi[] };
; CHECK:         MustWriteAccess :=  [Reduction Type: NONE] [Scalar: 0]
; CHECK:             { Stmt_bb18[i0] -> MemRef_A[i0] };
;
target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"

define void @f(i32* %A, i32 %b) {
bb:
  %tmp = sext i32 %b to i64
  %tmp1 = sext i32 %b to i64
  br label %bb2

bb2:                                              ; preds = %bb20, %bb
  %indvars.iv = phi i64 [ %indvars.iv.next, %bb20 ], [ 0, %bb ]
  %exitcond = icmp ne i64 %indvars.iv, 1024
  br i1 %exitcond, label %bb3, label %bb21

bb3:                                              ; preds = %bb2
  %tmp4 = getelementptr inbounds i32, i32* %A, i64 %indvars.iv
  %tmp5 = load i32,  i32* %tmp4, align 4
  %tmp6 = icmp eq i32 %tmp5, 0
  br i1 %tmp6, label %bb18, label %bb7

bb7:                                              ; preds = %bb3
  %tmp8 = icmp slt i64 %indvars.iv, %tmp
  br i1 %tmp8, label %bb9, label %bb10

bb9:                                              ; preds = %bb7
  br label %bb17

bb10:                                             ; preds = %bb7
  %tmp11 = shl nsw i64 %indvars.iv, 1
  %tmp12 = icmp sgt i64 %tmp11, %tmp1
  br i1 %tmp12, label %bb13, label %bb15

bb13:                                             ; preds = %bb10
  %tmp14 = trunc i64 %indvars.iv to i32
  br label %bb16

bb15:                                             ; preds = %bb10
  br label %bb16

bb16:                                             ; preds = %bb15, %bb13
  %x.0 = phi i32 [ %tmp14, %bb13 ], [ %b, %bb15 ]
  br label %bb17

bb17:                                             ; preds = %bb16, %bb9
  %x.1 = phi i32 [ 0, %bb9 ], [ %x.0, %bb16 ]
  br label %bb18

bb18:                                             ; preds = %bb3, %bb17
  %x.2 = phi i32 [ %x.1, %bb17 ], [ 0, %bb3 ]
  %tmp19 = getelementptr inbounds i32, i32* %A, i64 %indvars.iv
  store i32 %x.2, i32* %tmp19, align 4
  br label %bb20

bb20:                                             ; preds = %bb18
  %indvars.iv.next = add nuw nsw i64 %indvars.iv, 1
  br label %bb2

bb21:                                             ; preds = %bb2
  ret void
}