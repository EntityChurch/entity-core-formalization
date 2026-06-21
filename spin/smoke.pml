/*
 * Spin toolchain smoke — proves the verifier genuinely compiles and runs an EXHAUSTIVE check
 * end-to-end (spin -a -> gcc pan.c -> ./pan -> "errors: 0"), not just `spin -V`.
 * Throwaway sanity model, NOT a Core Protocol encoding. Two workers contend for a lock; the
 * assertion checks real mutual exclusion (at most one in the critical section) — so Spin is
 * verifying an actual safety property, which is the capability the cross-check will use.
 */
bool lock  = false;
byte ncrit = 0;       /* number of workers currently in the critical section */

active [2] proctype Worker() {
    atomic { (lock == false) -> lock = true }   /* acquire (test-and-set) */
    ncrit++;
    assert(ncrit == 1);                          /* mutual exclusion: never two in the CS */
    ncrit--;
    lock = false                                 /* release */
}
