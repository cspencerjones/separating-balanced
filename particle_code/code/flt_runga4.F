#include "FLT_OPTIONS.h"
#undef _USE_INTEGERS

      SUBROUTINE FLT_RUNGA4 (
     I                        myTime, myIter, myThid )

C     ==================================================================
C     SUBROUTINE FLT_RUNGA4
C     ==================================================================
C     o This routine steps floats forward with second order Runge-Kutta
C
C     started: Arne Biastoch
C
C     changed: 2004.06.10 Antti Westerlund (antti.westerlund@helsinki.fi)
C              and Sergio Jaramillo (sju@eos.ubc.ca)
C     ==================================================================

C     !USES:
      IMPLICIT NONE

C     == global variables ==
#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "GRID.h"
#include "DYNVARS.h"
#include "FLT_SIZE.h"
#include "FLT.h"
#include "OFFLINE.h"

C     == routine arguments ==
      _RL myTime
      INTEGER myIter, myThid

C     == Functions ==
#ifdef USE_FLT_ALT_NOISE
      Real*8   PORT_RAND_NORM
      EXTERNAL PORT_RAND_NORM
#else
      Real*8   PORT_RAND
      EXTERNAL PORT_RAND
#ifdef _USE_INTEGERS
      INTEGER seed
#else
      Real*8 seed
#endif
#endif /* USE_FLT_ALT_NOISE */

C     == local variables ==
      INTEGER bi, bj
      INTEGER ip
      INTEGER ic, jc, kc, iG, jG
      INTEGER i, j, k
      _RL uFld(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL vFld(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL wFld(1-OLx:sNx+OLx,1-OLy:sNy+OLy,Nr,nSx,nSy)
      _RL u1, v1, u2, v2, u3, v3, u4, v4
#ifdef ALLOW_3D_FLT
      _RL w1, w2, w3, w4, ktz1, ktz2, ktz3, kz, scalez
      _RL kzlo, kzhi
#endif
      _RL ix, jy, itx1, jty1, itx2, jty2, itx3, jty3
      _RL scalex, scaley

C     == end of interface ==

#ifndef USE_FLT_ALT_NOISE
#ifdef _USE_INTEGERS
      seed = -1
#else
      seed = -1.d0
#endif
#endif /* ndef USE_FLT_ALT_NOISE */

#ifdef ALLOW_3D_FLT
      kzlo = 0.5 _d 0
      kzhi = 0.5 _d 0 + DFLOAT(Nr)
#endif
      

      DO bj=myByLo(myThid),myByHi(myThid)
       DO bi=myBxLo(myThid),myBxHi(myThid)

        DO k=1,Nr
         DO j=1-OLy,sNy+OLy
          DO i=1-OLx,sNx+OLx
           uFld(i,j,k,bi,bj) = runFwd*uVel(i,j,k,bi,bj)
           vFld(i,j,k,bi,bj) = runFwd*vVel(i,j,k,bi,bj)
           wFld(i,j,k,bi,bj) = runFwd*wVel(i,j,k,bi,bj)
          ENDDO
         ENDDO
        ENDDO

         DO ip=1,npart_tile(bi,bj)

C     If float has died move to level 0
           IF ( tend(ip,bi,bj).NE.-1. .AND. myTime.GT.tend(ip,bi,bj)
     &        ) THEN
            kpart(ip,bi,bj) = 0.
           ELSE
C     Start integration between tstart and tend (individual for each float)
            IF ( (tstart(ip,bi,bj).EQ.-1..OR.myTime.GE.tstart(ip,bi,bj))
     &      .AND.(  tend(ip,bi,bj).EQ.-1..OR.myTime.LE.  tend(ip,bi,bj))
     &      .AND.(   iup(ip,bi,bj).NE.-3.)
     &         ) THEN

              ix = ipart(ip,bi,bj)
              jy = jpart(ip,bi,bj)
              ic=NINT(ix)
              jc=NINT(jy)
              kc=NINT(kpart(ip,bi,bj))

              scalex=recip_dxF(ic,jc,bi,bj)
              scaley=recip_dyF(ic,jc,bi,bj)
              iG = myXGlobalLo + (bi-1)*sNx + ic-1
              jG = myYGlobalLo + (bj-1)*sNy + jc-1


C     First step

#ifdef ALLOW_3D_FLT
              IF (iup(ip,bi,bj).EQ.-1.) THEN
c               kz=global2local_k(kpart(ip,bi,bj),bi,bj,mjtyhid)

C recip_drF is in units 1/r (so IF r is in m this is in 1/m)
                scalez=rkSign*recip_drF(kc)
C We should not do any special conversions for kz, since flt_trilinear
C expects it to be just a normal kpart type variable.
                kz=kpart(ip,bi,bj)
                CALL FLT_TRILINEAR(ix,jy,kz,u1,uFld,1,bi,bj
     &                              ,myThid)
                CALL FLT_TRILINEAR(ix,jy,kz,v1,vFld,2,bi,bj
     &                                ,myThid)
                CALL FLT_TRILINEAR(ix,jy,kz,w1,wFld,4,bi,bj
     &                                ,myThid)
              ELSE
#else  /* ALLOW_3D_FLT */
              IF ( .TRUE. ) THEN
#endif /* ALLOW_3D_FLT */
                CALL FLT_BILINEAR(ix,jy,u1,uFld,kc,1,bi,bj
     &                                ,myThid)
                CALL FLT_BILINEAR(ix,jy,v1,vFld,kc,2,bi,bj
     &                                  ,myThid)
              ENDIF

C When using this alternative scheme the noise probably should not be added twice.
#ifndef USE_FLT_ALT_NOISE
              IF ( flt_noise.NE.0. .AND. iup(ip,bi,bj).NE.-2. ) THEN
                u1 = u1 + u1*(PORT_RAND(seed)-0.5)*flt_noise
                v1 = v1 + v1*(PORT_RAND(seed)-0.5)*flt_noise
#ifdef ALLOW_3D_FLT
#ifdef ALLOW_FLT_3D_NOISE
                IF (iup(ip,bi,bj).EQ.-1.) THEN
                  w1 = w1 + w1*(PORT_RAND(seed)-0.5)*flt_noise
                ENDIF
#endif
#endif /* ALLOW_3D_FLT */
              ENDIF
#endif /* ndef USE_FLT_ALT_NOISE */

C ix and itx are in indices. Therefore it is necessary to multiply
C with a grid scale factor.

              itx1=ix+0.5*flt_deltaT*u1*scalex
              jty1=jy+0.5*flt_deltaT*v1*scaley

C     Second step

#ifdef ALLOW_3D_FLT
              IF (iup(ip,bi,bj).EQ.-1.) THEN
                ktz1=kz+0.5*flt_deltaT*w1*scalez
                CALL FLT_TRILINEAR(itx1,jty1,ktz1,u2,uFld,
     &               1,bi,bj,myThid)
                CALL FLT_TRILINEAR(itx1,jty1,ktz1,v2,vFld,
     &               2,bi,bj,myThid)
                CALL FLT_TRILINEAR(itx1,jty1,ktz1,w2,wFld,
     &               4,bi,bj,myThid)
              ELSE
#else  /* ALLOW_3D_FLT */
              IF ( .TRUE. ) THEN
#endif /* ALLOW_3D_FLT */
                CALL FLT_BILINEAR(itx1,jty1,u2,uFld,
     &               kc,1,bi,bj,myThid)
                CALL FLT_BILINEAR(itx1,jty1,v2,vFld,
     &               kc,2,bi,bj,myThid)
              ENDIF

              IF ( flt_noise.NE.0. .AND. iup(ip,bi,bj).NE.-2. ) THEN
#ifdef USE_FLT_ALT_NOISE
                u2 = u2 + PORT_RAND_NORM()*flt_noise
                v2 = v2 + PORT_RAND_NORM()*flt_noise
#ifdef ALLOW_3D_FLT
#ifdef ALLOW_FLT_3D_NOISE
                IF (iup(ip,bi,bj).EQ.-1.) THEN
                  w2 = w2 + PORT_RAND_NORM()*flt_noise
                ENDIF
#endif
#endif /* ALLOW_3D_FLT */

#else /* USE_FLT_ALT_NOISE */
                u2 = u2 + u2*(PORT_RAND(seed)-0.5)*flt_noise
                v2 = v2 + v2*(PORT_RAND(seed)-0.5)*flt_noise
#ifdef ALLOW_3D_FLT
#ifdef ALLOW_FLT_3D_NOISE
                IF (iup(ip,bi,bj).EQ.-1.) THEN
                  w2 = w2 + w2*(PORT_RAND(seed)-0.5)*flt_noise
                ENDIF
#endif
#endif /* ALLOW_3D_FLT */

#endif /* USE_FLT_ALT_NOISE */
              ENDIF

              itx2=ix+0.5*flt_deltaT*u2*scalex
              jty2=jy+0.5*flt_deltaT*v2*scaley

C     Third step

#ifdef ALLOW_3D_FLT
              IF (iup(ip,bi,bj).EQ.-1.) THEN
                ktz2=kz+0.5*flt_deltaT*w2*scalez
                CALL FLT_TRILINEAR(itx2,jty2,ktz2,u3,uFld,
     &               1,bi,bj,myThid)
                CALL FLT_TRILINEAR(itx2,jty2,ktz2,v3,vFld,
     &               2,bi,bj,myThid)
                CALL FLT_TRILINEAR(itx2,jty2,ktz2,w3,wFld,
     &               4,bi,bj,myThid)
              ELSE
#else  /* ALLOW_3D_FLT */
              IF ( .TRUE. ) THEN
#endif /* ALLOW_3D_FLT */
                CALL FLT_BILINEAR(itx2,jty2,u3,uFld,
     &               kc,1,bi,bj,myThid)
                CALL FLT_BILINEAR(itx2,jty2,v3,vFld,
     &               kc,2,bi,bj,myThid)
              ENDIF

              IF ( flt_noise.NE.0. .AND. iup(ip,bi,bj).NE.-2. ) THEN
#ifdef USE_FLT_ALT_NOISE
                u3 = u3 + PORT_RAND_NORM()*flt_noise
                v3 = v3 + PORT_RAND_NORM()*flt_noise
#ifdef ALLOW_3D_FLT
#ifdef ALLOW_FLT_3D_NOISE
                IF (iup(ip,bi,bj).EQ.-1.) THEN
                  w3 = w3 + PORT_RAND_NORM()*flt_noise
                ENDIF
#endif
#endif /* ALLOW_3D_FLT */

#else /* USE_FLT_ALT_NOISE */
                u3 = u3 + u3*(PORT_RAND(seed)-0.5)*flt_noise
                v3 = v3 + v3*(PORT_RAND(seed)-0.5)*flt_noise
#ifdef ALLOW_3D_FLT
#ifdef ALLOW_FLT_3D_NOISE
                IF (iup(ip,bi,bj).EQ.-1.) THEN
                  w3 = w3 + w3*(PORT_RAND(seed)-0.5)*flt_noise
                ENDIF
#endif
#endif /* ALLOW_3D_FLT */

#endif /* USE_FLT_ALT_NOISE */
              ENDIF

              itx3=ix+flt_deltaT*u3*scalex
              jty3=jy+flt_deltaT*v3*scaley

C     Fourth step

#ifdef ALLOW_3D_FLT
              IF (iup(ip,bi,bj).EQ.-1.) THEN
                ktz3=kz+0.5*flt_deltaT*w2*scalez
                CALL FLT_TRILINEAR(itx3,jty3,ktz3,u4,uFld,
     &               1,bi,bj,myThid)
                CALL FLT_TRILINEAR(itx3,jty3,ktz3,v4,vFld,
     &               2,bi,bj,myThid)
                CALL FLT_TRILINEAR(itx3,jty3,ktz3,w4,wFld,
     &               4,bi,bj,myThid)
              ELSE
#else  /* ALLOW_3D_FLT */
              IF ( .TRUE. ) THEN
#endif /* ALLOW_3D_FLT */
                CALL FLT_BILINEAR(itx3,jty3,u4,uFld,
     &               kc,1,bi,bj,myThid)
                CALL FLT_BILINEAR(itx3,jty3,v4,vFld,
     &               kc,2,bi,bj,myThid)
              ENDIF

              IF ( flt_noise.NE.0. .AND. iup(ip,bi,bj).NE.-2. ) THEN
#ifdef USE_FLT_ALT_NOISE
                u4 = u4 + PORT_RAND_NORM()*flt_noise
                v4 = v4 + PORT_RAND_NORM()*flt_noise
#ifdef ALLOW_3D_FLT
#ifdef ALLOW_FLT_3D_NOISE
                IF (iup(ip,bi,bj).EQ.-1.) THEN
                  w4 = w4 + PORT_RAND_NORM()*flt_noise
                ENDIF
#endif
#endif /* ALLOW_3D_FLT */

#else /* USE_FLT_ALT_NOISE */
                u4 = u4 + u4*(PORT_RAND(seed)-0.5)*flt_noise
                v4 = v4 + v4*(PORT_RAND(seed)-0.5)*flt_noise
#ifdef ALLOW_3D_FLT
#ifdef ALLOW_FLT_3D_NOISE
                IF (iup(ip,bi,bj).EQ.-1.) THEN
                  w4 = w4 + w4*(PORT_RAND(seed)-0.5)*flt_noise
                ENDIF
#endif
#endif /* ALLOW_3D_FLT */

#endif /* USE_FLT_ALT_NOISE */
              ENDIF

C ipart is in coordinates. Therefore it is necessary to multiply
C with a grid scale factor divided by the number grid points per
C geographical coordinate.
              ipart(ip,bi,bj) = ipart(ip,bi,bj) + flt_deltaT/6
     &                        * (u1 + 2*u2 + 2*u3 + u4) * scalex
              jpart(ip,bi,bj) = jpart(ip,bi,bj) + flt_deltaT/6
     &                        * (v1 + 2*v2 + 2*v3 + v4) * scaley
#ifdef ALLOW_3D_FLT
              IF (iup(ip,bi,bj).EQ.-1.) THEN
                kpart(ip,bi,bj) = kpart(ip,bi,bj) + flt_deltaT/6
     &                          * (w1 + 2*w2 + 2*w3 + w4) * scalez
              ENDIF
#endif /* ALLOW_3D_FLT */

C--  new horizontal grid indices
              ic = MAX( 1-OLx, MIN( NINT(ipart(ip,bi,bj)), sNx+OLx ) )
              jc = MAX( 1-OLy, MIN( NINT(jpart(ip,bi,bj)), sNy+OLy ) )

#ifdef ALLOW_3D_FLT
C If float is 3D, make sure that it remains in water
              IF (iup(ip,bi,bj).EQ.-1.) THEN
C reflect on surface
                IF (kpart(ip,bi,bj).LT.kzlo) kpart(ip,bi,bj)=kzlo
     &                                      +kzlo-kpart(ip,bi,bj)
C stop at bottom
                IF (kpart(ip,bi,bj).GT.kzhi) kpart(ip,bi,bj)=kzhi
C-to work also with non flat-bottom set-up:
c               IF ( kpart(ip,bi,bj).GT.kLowC(ic,jc,bi,bj)+0.5 )
c    &               kpart(ip,bi,bj) = kLowC(ic,jc,bi,bj)+0.5
              ENDIF
#endif /* ALLOW_3D_FLT */

#ifdef ALLOW_OBCS
              IF ( useOBCS ) THEN
C--  stop floats which enter the OB region:
               IF ( maskInC(ic,jc,bi,bj).EQ.0. .AND.
     &              maskC(ic,jc,1,bi,bj).EQ.1. ) THEN
C    for now, just reset "tend" to myTime-deltaT
C    (a better way would be to remove this one & re-order the list of floats)
                  tend(ip,bi,bj) = myTime - flt_deltaT
               ENDIF
              ENDIF
#endif /* ALLOW_OBCS */

            ENDIF
           ENDIF

C-    end ip loop
         ENDDO
C-    end bi,bj loops
       ENDDO
      ENDDO

      RETURN
      END
