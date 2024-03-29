#include "FLT_OPTIONS.h"

      SUBROUTINE FLT_INIT_VARIA ( myThid  )

C     CSJ modified this version of FLT_INIT_VARIA to work in 
C     tutorial_baroclinic_gyre and to intialize particles 
C     Key points: 
C            -in order to start particles, set FLT_Iter0=Iter0
C            - the variable sqrtFperC must be set in this code
C               it defines the sqrt of the no of floats/cell



C     ==================================================================
C     SUBROUTINE FLT_INIT_VARIA
C     ==================================================================
C     o This routine initializes the start/restart positions.
C     o Either read initial position from file "flt_file" or
C       read pickup file. The 2 type of files are similar, except
C       initial positions are given on grid-coordinate (distance/degree
C       depending on the grid) whereas in pickup file, positions are
C       fractional indices along the grid and local to the tile.
C       For this reason global pickup file is not supported.
C       Initialisation:
C     o First it check for global file, and when found, reads the global file
C       (that has the same format as local files) and sorts those floats
C       that exist on the specific tile into the local array.
C     o If no global file is available or in a case of a restart (pickup
C       file from a previous integration) then read tiled file without
C       any further check (because they exist on the specific tile).
C     ==================================================================

C     !USES:
      IMPLICIT NONE

#include "SIZE.h"
#include "EEPARAMS.h"
#include "PARAMS.h"
#include "FLT_SIZE.h"
#include "FLT.h"

C     == routine arguments ==
C     myThid - thread number for this instance of the routine.
      INTEGER myThid

C     == Functions ==
      INTEGER  ILNBLNK
      EXTERNAL ILNBLNK
      _RL      FLT_MAP_R2K
      EXTERNAL FLT_MAP_R2K

C     == local variables ==
      INTEGER bi, bj
      INTEGER ip, iL
      INTEGER imax
      PARAMETER(imax=9)
      _RL tmp(imax)
      _RS dummyRS(1)
      _RL ix, jy, kz
      _RL iLo, iHi, jLo, jHi
      INTEGER fp, ioUnit
      CHARACTER*(MAX_LEN_FNAM) fn
      CHARACTER*(MAX_LEN_MBUF) msgBuf
      CHARACTER*(10) suff
      INTEGER iG,jG,i,j,icount
      INTEGER iFpC,jFpC
      INTEGER k


C     number of active record in the file (might be lower than the
C     total number of records because the tile could have contained
C     more floats at an earlier restart
      INTEGER npart_read
      _RL     npart_dist


C     == end of interface ==




C-    Tile boundary on index map:
      iLo = 0.5 _d 0
      iHi = 0.5 _d 0 + DFLOAT(sNx)
      jLo = 0.5 _d 0
      jHi = 0.5 _d 0 + DFLOAT(sNy)

C-    all threads initialise local var:
      npart_read = 0
      npart_dist = 0.

      _BEGIN_MASTER(myThid)

      DO bj = 1,nSy
       DO bi = 1,nSx
        npart_tile(bi,bj) = 0
       ENDDO
      ENDDO

C read floats initial condition from file
      IF ( nIter0.EQ.FLT_Iter0 ) THEN
        fn = flt_file
        fp = readBinaryPrec
      ELSEIF ( nIter0.GT.FLT_Iter0 ) THEN
        IF ( pickupSuff .EQ. ' ' ) THEN
          IF ( rwSuffixType.EQ.0 ) THEN
            WRITE(suff,'(I10.10)') nIter0
          ELSE
            CALL RW_GET_SUFFIX( suff, startTime, nIter0, myThid )
          ENDIF
        ELSE
          WRITE(suff,'(A10)') pickupSuff
        ENDIF
        WRITE(fn,'(A,A10)') 'pickup_flt.',suff
        fp = precFloat64
      ELSE
        WRITE(msgBuf,'(2A,I3,A)') 'FLT_INIT_VARIA:',
     &       ' wrong setting of FLT_Iter0 :'
        CALL PRINT_ERROR( msgBuf, myThid )
        WRITE(msgBuf,'(2A,I3,A)') 'FLT_INIT_VARIA:',
     &       ' nIter0 < FLT_Iter0 not supported'
        CALL PRINT_ERROR( msgBuf, myThid )
        STOP 'ABNORMAL END: S/R FLT_INIT_VARIA'
      ENDIF
      iL = ILNBLNK(fn)
      WRITE(msgBuf,'(2A)')
     &   'FLT_INIT_VARIA: reading Floats from: ', fn(1:iL)
      CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                    SQUEEZE_RIGHT, myThid )

C---+----1----+----2----+----3----+----4----+----5----+----6----+----7-|--+----|

C--   Initial position: first try to read from a global file.
      ioUnit = -2
      bi = 0
      bj = 0
      IF ( nIter0.EQ.FLT_Iter0 ) THEN
C-    read actual number of floats from file
        CALL MDS_READVEC_LOC( fn, fp, ioUnit,
     &                        'RL', imax, tmp, dummyRS,
     &                        bi, bj, 1, myThid )
      ENDIF

      IF ( ioUnit.GT.0 .AND. mapIniPos2Index ) THEN
C--   Found a global file
        WRITE(msgBuf,'(A,2I4,A,1P2E15.8)')
     &    ' bi,bj=', bi, bj, ' , npart,max_npart=', tmp(1), tmp(6)
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                       SQUEEZE_RIGHT, myThid )
        npart_read = NINT(tmp(1))
        max_npart  = tmp(6)
        DO ip=1,npart_read
C-    read individual float position from file
          CALL MDS_READVEC_LOC( fn, fp, ioUnit,
     &                          'RL', imax, tmp, dummyRS,
     &                          bi, bj, ip+1, myThid )
          DO bj = 1,nSy
           DO bi = 1,nSx
C-    For initial condition only, convert coordinates to index map:
            CALL FLT_MAP_XY2IJLOCAL( ix, jy,
     I                               tmp(3), tmp(4),bi,bj,myThid )
            kz = FLT_MAP_R2K( tmp(5), bi, bj, myThid )
C-    Check if float exists on this tile. If not, try next tile
            IF ( ix.GE.iLo .AND. ix.LT.iHi .AND.
     &           jy.GE.jLo .AND. jy.LT.jHi ) THEN
             npart_tile(bi,bj) = npart_tile(bi,bj) + 1
             IF ( npart_tile(bi,bj).LE.max_npart_tile ) THEN

              npart( npart_tile(bi,bj),bi,bj) = tmp(1)
              tstart(npart_tile(bi,bj),bi,bj) = tmp(2)
              ipart( npart_tile(bi,bj),bi,bj) = ix
              jpart( npart_tile(bi,bj),bi,bj) = jy
              kpart( npart_tile(bi,bj),bi,bj) = kz
              kfloat(npart_tile(bi,bj),bi,bj) = tmp(6)
              iup(   npart_tile(bi,bj),bi,bj) = tmp(7)
              itop(  npart_tile(bi,bj),bi,bj) = tmp(8)
              tend(  npart_tile(bi,bj),bi,bj) = tmp(9)

             ENDIF
            ENDIF
C-      end bi,bj loops
           ENDDO
          ENDDO

        ENDDO
        CLOSE( ioUnit )

      ELSEIF ( ioUnit.GT.0 ) THEN
         WRITE(msgBuf,'(2A)') 'FLT_INIT_VARIA:',
     &                ' need mapIniPos2Index=T for global file'
         CALL PRINT_ERROR( msgBuf , myThid)
         STOP 'ABNORMAL END: S/R FLT_INIT_VARIA'

      ELSE
C--   then try to read from a tiled file:

CSJ-----------
          icount=0
CSJ------------
        DO bj = 1,nSy
         DO bi = 1,nSx
CSJ----    Add code to write particles
          iG=bi+(myXGlobalLo-1)/sNx
          jG=bj+(myYGlobalLo-1)/sNy
          WRITE(msgBuf,'(A,I4,A,I4)') 'iG,jG=',iG,',',jG
          CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                       SQUEEZE_RIGHT, myThid )
c
           npart_tile(bi,bj) = sNx*sNy*flt_sqrtFperC**2
     &                                 *kno
           max_npart  = sNx*sNy*flt_sqrtFperC**2
     &                            *kno*5
           npart_read = 1
c           
           ip=1
           DO jFpC=1,flt_sqrtFperC
            DO iFpC=1,flt_sqrtFperC
             DO j=1,sNy
              DO i=1,sNx
               DO k=1,kno
                icount=icount+1
                npart(ip,bi,bj)  = (DBLE(jG)-1)*nSx*nPx
     &                                   *DBLE(sNx)*DBLE(sNy)*DBLE(kno)+
     &                             (DBLE(iG)-1)*DBLE(sNx)*DBLE(sNy)
     &                                          *DBLE(kno)+
     &                              DBLE(icount)
                tstart(ip,bi,bj) = -1. _d 0
                ipart(ip,bi,bj)  = i+(DBLE(iFpC)-1)
     &                               /DBLE(flt_sqrtFperC)
                jpart(ip,bi,bj)  = j+(DBLE(jFpC)-1)
     &                               /DBLE(flt_sqrtFperC)
                kpart(ip,bi,bj)  =  flt_klevels(k)
                kfloat(ip,bi,bj) = 0. _d 0
                iup(  ip,bi,bj)  = 0. _d 0
                itop( ip,bi,bj)  = 0. _d 0
                tend( ip,bi,bj)  = -1. _d 0
                ip=ip+1
               ENDDO
              ENDDO
             ENDDO
            ENDDO
           ENDDO
CSJ----    End of code to write particles

C-      end bi,bj loops
         ENDDO
        ENDDO

C--   end global-file / tiled-file separated treatment
      ENDIF

      DO bj = 1,nSy
       DO bi = 1,nSx
         npart_dist = npart_dist + DBLE(npart_tile(bi,bj))
         IF ( npart_tile(bi,bj).GT.max_npart_tile ) THEN
           WRITE(msgBuf,'(2A,2I4,2(A,I8))') 'FLT_INIT_VARIA:',
     &       ' bi,bj=', bi, bj,
     &       ' npart_tile=', npart_tile(bi,bj),
     &       ' > max_npart_tile=', max_npart_tile
           CALL PRINT_ERROR( msgBuf , myThid)
           STOP 'ABNORMAL END: S/R FLT_INIT_VARIA'
         ENDIF
       ENDDO
      ENDDO
      _END_MASTER( myThid )
      _BARRIER

      _GLOBAL_SUM_RL( npart_dist, myThid )

      _BEGIN_MASTER( myThid )
        WRITE(msgBuf,'(A,2(A,I9))') 'FLT_INIT_VARIA:',
     &          ' max npart=', NINT(max_npart),
     &   ' , sum npart_tile=', NINT(npart_dist)
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
        WRITE(msgBuf,'(A)') ' '
        CALL PRINT_MESSAGE( msgBuf, standardMessageUnit,
     &                      SQUEEZE_RIGHT, myThid )
      _END_MASTER( myThid )

C--   Initial call just to check which variables to write
      IF ( flt_int_prof.NE.0. )
     &  CALL FLT_UP( startTime, nIter0, myThid )
      IF ( flt_int_traj.NE.0. )
     &  CALL FLT_TRAJ( startTime, nIter0, myThid )

      RETURN
      END
