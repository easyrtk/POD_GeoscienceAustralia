MODULE m_eop_data


! ----------------------------------------------------------------------
! MODULE: m_eop_data.f03
! ----------------------------------------------------------------------
! Purpose:
!  Module for callnig the eop_data subroutine 
! 
! ----------------------------------------------------------------------
! Author :	Dr. Thomas Papanikolaou, Geoscience Australia 
! Created:	23 July 2018
! ----------------------------------------------------------------------


      IMPLICIT NONE
      !SAVE 			
 
	  
Contains


SUBROUTINE eop_data (mjd, EOP_fname, EOP_sol, n_interp , EOP_days)


! ----------------------------------------------------------------------
! Subroutine:  eop_data.f90
! ----------------------------------------------------------------------
! Purpose:
!  IERS Earth Orientation Parameters (EOP) data reading and processing.
!  Corrections computing due to tidal variations
! ----------------------------------------------------------------------
! Input arguments:
! - mjd:			Modified Julian Day number of the epoch (in TT)
! - EOP_fname:		EOP data file name  e.g. 'eopc04_IAU2000.62-now'
! - EOP_sol:		EOP solution type (see Note 1)
! - n_interp:		number of points to be used for EOP data interpolation 
!
! Output arguments:
! - EOP_cr:		Array of the EOP data after applying the tidal corrections
!   EOP_cr = [MJD xp_cor yp_cor UT1-UTC_cor LOD_cor dX dY]  1x6 matrix
!   MJD:     		MJD of the input epoch (in TT)
!   xp_cor,yp_cor:	Polar motion coordinates (arcsec) at input epoch considering 
!					corrections due to tidal variations (ocean tidal and libration effects)  	
!   UT1UTC_cor:		UT1-UTC difference (sec) at input epoch considering corrections
!					due to tidal variations	(ocean tidal and libration effects)  
!   LOD:			Length of Day (LOD)
!   dX, dY:			Corrections to the Precession-Nutation model (arcsec)
! ----------------------------------------------------------------------
! Note 1:
! Values of the EOP_sol input argument:
! 1. EOP_sol = 1 : refers to EOP data format of the C04 solution
!    			   provided by the IERS Earth Orientation Center 
! 2. EOP_sol = 2 : refers to EOP data format of the daily solution (finals2000A.daily)
!    			   provided by the IERS Rapid Service/Prediction Center
! 3. EOP_sol = 3 : refers to EOP data format of the ultra-rapid products
!    			   provided by the IGS (per every 6 hours)
! ----------------------------------------------------------------------
! Author :	Dr. Thomas Papanikolaou, Geoscience Australia 
! Created:	23 July 2018
! ----------------------------------------------------------------------



      USE mdl_precision
      USE mdl_num
      IMPLICIT NONE

! ----------------------------------------------------------------------
! Dummy arguments declaration
! ----------------------------------------------------------------------
! IN
      REAL (KIND = prec_d), INTENT(IN) :: mjd
      CHARACTER (LEN=50), INTENT(IN) :: EOP_fname
      INTEGER (KIND = prec_int4), INTENT(IN) :: n_interp
      INTEGER (KIND = prec_int1), INTENT(IN) :: EOP_sol
! OUT
      !REAL (KIND = prec_d), INTENT(OUT) :: EOP_data(n_interp,7)
      REAL (KIND = prec_d), INTENT(OUT), DIMENSION(:,:), ALLOCATABLE :: EOP_days	  
! ----------------------------------------------------------------------


! ----------------------------------------------------------------------
! Local variables declaration
! ----------------------------------------------------------------------
      REAL (KIND = prec_d) :: mjd_TT, mjd_GPS, mjd_TAI, mjd_UTC, mjd_UT1
      DOUBLE PRECISION TT1, TT2, TT1_UT1, TT2_UT1, TAI1, TAI2
      INTEGER (KIND = prec_int8) :: mjd_UTC_day
      REAL (KIND = prec_d) :: EOP_day(7)
      DOUBLE PRECISION xp, yp, xp_int, yp_int, xp_cor, yp_cor
      DOUBLE PRECISION dUT1_UTC, ut1utc_int, UT1UTC_cor
      DOUBLE PRECISION dX_eop, dY_eop, LOD 
! ----------------------------------------------------------------------
      INTEGER (KIND = prec_int8) :: MJD_day, MJD_i, n_cent
      INTEGER (KIND = prec_int4) :: i
      REAL (KIND = prec_d) :: EOP_i(7)
      REAL (KIND = prec_d) :: MJDint_ar(n_interp), xint_ar(n_interp), yint_ar(n_interp), UT1int_ar(n_interp)
! ----------------------------------------------------------------------
      INTEGER (KIND = prec_int2) :: AllocateStatus, DeAllocateStatus  


	  
! ----------------------------------------------------------------------
! Dynamic allocatable arrays
ALLOCATE (EOP_days(n_interp,7), STAT = AllocateStatus)
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
! Time Systems transformation											 
! ----------------------------------------------------------------------
      CALL time_TT (mjd , mjd_TT, mjd_GPS, mjd_TAI, mjd_UTC)
! ----------------------------------------------------------------------
! TT
      TT1 = 2400000.5D0
      TT2 = mjd_TT
! ----------------------------------------------------------------------
! TAI
      TAI1 = 2400000.5D0
      TAI2 = mjd_TAI
! ----------------------------------------------------------------------
! UTC
      mjd_UTC_day = INT (mjd_UTC)
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
! EOP data reading
! ----------------------------------------------------------------------
      CALL eop_rd (EOP_fname, EOP_sol, mjd_UTC_day , EOP_day)
! xp,yp (arcsec)
      xp = EOP_day(2)
      yp = EOP_day(3)
! UT1-UTC (sec)
      dUT1_UTC = EOP_day(4)
! LOD (sec)
	  LOD = EOP_day(5)
! dX,dY (arcsec)													
      dX_eop = EOP_day(6)
      dY_eop = EOP_day(7)
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
! Epochs center definition
      IF (n_interp/2 - INT(n_interp/2) == 0) THEN
	     n_cent = n_interp/2
      ELSE
         n_cent = INT(n_interp/2) + 1
      END IF
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
DO i = 1 , n_interp
   MJD_i = mjd_UTC_day - n_cent + i
   CALL eop_rd (EOP_fname, EOP_sol, MJD_i , EOP_i)
   MJDint_ar(i) = MJD_i
   xint_ar(i) = EOP_i(2)
   yint_ar(i) = EOP_i(3)
   UT1int_ar(i) = EOP_i(4)
		 
! LOD (sec)
   LOD = EOP_i(5)
! dX,dY (arcsec)													
   dX_eop = EOP_i(6)
   dY_eop = EOP_i(7)

EOP_days(i,1) = MJD_i
EOP_days(i,2) = EOP_i(2)
EOP_days(i,3) = EOP_i(3)
EOP_days(i,4) = EOP_i(4)
EOP_days(i,5) = EOP_i(5)
EOP_days(i,6) = EOP_i(6)
EOP_days(i,7) = EOP_i(7)

      END DO
! ----------------------------------------------------------------------


END SUBROUTINE


END
