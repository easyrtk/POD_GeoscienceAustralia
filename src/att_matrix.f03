SUBROUTINE att_matrix(mjd, rsat_icrf, vsat_icrf, PRNsat, satsinex_filename, & 
				& 	  eclipse_status, Yangle_array, Rtrf2bff, Quaternions_trf2bff)


! ----------------------------------------------------------------------
! SUBROUTINE: att_matrix.f03
! ----------------------------------------------------------------------
! Purpose:
!  Compute satellite attitude and transformation matrix between 
!  terrestrial reference frame and satellite body-fixed frame
! ----------------------------------------------------------------------
! Input arguments:
! - mjd:			Modified Julian Day number (including fraction of the day)
! - rsat_icrf: 		Satellie position vector (m) 
! - vsat_icrf: 		Satellie velocity vector (m/sec)
! - PRNsat:			PRN number of GNSS satellites
!
! Output arguments:
! - eclipse_status:	Satellite attitude' flag according to eclipse status:
!					0 = Nominal attitude
!					1 = Non-nominal, midnight turn due to eclipse
!					2 = Non-nominal, noon turn due to eclipse
! - Yangle: 		Yaw angle array (in degrees) with 2 values: Yaw nominal and Yaw modelled
!					During nominal periods, the two values are equal
! - Yangle_array:	Yaw angle (in degrees) array based on nominal attitude and eclipsing model (during eclipse season)
! 					Yaw_angle(1) = Yaw nominal based on nominal attitude 
! 					Yaw_angle(2) = Yaw eclipsing based on attitude model applied during eclipse period 
! 					In case of out of eclipse season, the two values are same and equal to Yaw angle of nominal attitude  
! - Rtrf2bff : 		Transformation matrix: Terrestrial reference frame to satellite body-fixed frame 
! - Quaternions_trf2bff: Quaternions of the transformation matrix between terrestrial reference frame and satellite body-fixed frame 
! ----------------------------------------------------------------------
! Author :	Dr. Thomas Papanikolaou at Geoscience Australia
! Created:	10 December 2019
! ----------------------------------------------------------------------


      USE mdl_precision
      USE mdl_num
      USE mdl_param
      USE m_matrixinv
      USE m_read_satsnx
      IMPLICIT NONE
	  
! ----------------------------------------------------------------------
! Dummy arguments declaration
! ----------------------------------------------------------------------
! IN
      REAL (KIND = prec_d) :: mjd
      REAL (KIND = prec_q), INTENT(IN) :: rsat_icrf(3), vsat_icrf(3)
      CHARACTER (LEN=3) , INTENT(IN) :: PRNsat
      CHARACTER (LEN=100), INTENT(IN) :: satsinex_filename
      INTEGER (KIND = 4) :: eclipse_status
      REAL (KIND = prec_d) :: Yangle_array(2)	  
! OUT
      REAL (KIND = prec_q), INTENT(OUT) :: Rtrf2bff(3,3)
      REAL (KIND = prec_q), INTENT(OUT) :: Quaternions_trf2bff(4)
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
! Local variables declaration
! ----------------------------------------------------------------------
      INTEGER (KIND = 4) :: satblk
      CHARACTER (LEN=5)  :: BDSorbtype
      REAL (KIND = prec_d) :: Sec_00, jd0, mjd_1
      !INTEGER (KIND = prec_int4) :: IY, IM, ID
      INTEGER Iyear, Imonth, Iday, J_flag
      DOUBLE PRECISION FD  
      INTEGER (KIND = prec_int4) :: DOY
      DOUBLE PRECISION  JD, Zbody(6)
      INTEGER  NTARG, NCTR, NTARG_body
      REAL (KIND = prec_q), DIMENSION(3) :: rbody
      REAL (KIND = prec_q), DIMENSION(3) :: rSun 		
      REAL (KIND = prec_d) :: beta, Mangle, Yaw_angle
	  REAL (KIND = prec_d) , Dimension(3) :: eBX_nom, eBX_ecl

      REAL (KIND = prec_d) :: Rcrf_bff(3,3), Rrtn_bff(3,3)
      REAL (KIND = prec_d) :: Rbff2crf(3,3)
      REAL (KIND = prec_d) :: Rbff2trf(3,3)
      INTEGER (KIND = prec_int8) :: An
      REAL (KIND = prec_d) :: EOP_cr(7)
      REAL (KIND = prec_d) :: CRS2TRS(3,3), TRS2CRS(3,3)
      REAL (KIND = prec_d) :: d_CRS2TRS(3,3), d_TRS2CRS(3,3)
	  DOUBLE PRECISION, Dimension(4) :: quater 
! ----------------------------------------------------------------------




! ----------------------------------------------------------------------
! Read SINEX file for satellite metadata (SVN number,Satellite Block type,..)  
! ----------------------------------------------------------------------
   Sec_00 = ( mjd - INT(mjd) ) * 86400.0D0
   jd0 = 2400000.5D0
   CALL iau_JD2CAL ( jd0, mjd, Iyear, Imonth, Iday, FD, J_flag )
   CALL iau_CAL2JD ( Iyear, 1, 1, jd0, mjd_1, J_flag )   
   DOY = INT(mjd) - (mjd_1-1) 
   
   ! Read Sinex dta flie
   CALL read_satsnx (satsinex_filename, Iyear, DOY, Sec_00, PRNsat) 
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
! GNSS Satellite Block Type
! ----------------------------------------------------------------------
! BLK_TYP :: Global variable in mdl_param
! ----------------------------------------------------------------------
! GPS case: Satellite Block ID:        1=I, 2=II, 3=IIA, IIR=(4, 5), IIF=6
satblk = 3
IF(BLKTYP=='GPS-I')			  THEN
	satblk = 1
ELSE IF(BLKTYP=='GPS-II')	  THEN
	satblk = 2
ELSE IF(BLKTYP=='GPS-IIA') 	  THEN
	satblk = 3
ELSE IF(BLKTYP=='GPS-IIR')	  THEN
	satblk = 4
ELSE IF(BLKTYP=='GPS-IIR-A')  THEN
	satblk = 5
ELSE IF(BLKTYP=='GPS-IIR-B')  THEN
	satblk = 5
ELSE IF(BLKTYP=='GPS-IIR-M')  THEN
	satblk = 5
ELSE IF(BLKTYP=='GPS-IIF')    THEN
	satblk = 6
END IF
! ----------------------------------------------------------------------
! Beidou case: 'IGSO', 'MEO'
! 1. BDSorbtype = 'IGSO'
! 2. BDSorbtype = 'MEO'
! 3. BDSorbtype = 'IGSO'
IF(BLKTYP=='BDS-2G'.or.BLKTYP == 'BDS-3G')            BDSorbtype = 'GEO'  
IF(BLKTYP=='BDS-2I'.or.BLKTYP == 'BDS-3I'.or.&
   BLKTYP=='BDS-3SI-SECM'.or.BLKTYP =='BDS-3SI-CAST') BDSorbtype = 'IGSO' 
IF(BLKTYP=='BDS-2M'.or.BLKTYP == 'BDS-3M'.or.&
   BLKTYP=='BDS-3M-SECM'.or.BLKTYP =='BDS-3M-CAST')   BDSorbtype = 'MEO'
! ----------------------------------------------------------------------


! ----------------------------------------------------------------------
! Sun position vector computation
! ----------------------------------------------------------------------
NTARG_body = 11

! Julian Day Number of the input epoch
JD = mjd + 2400000.5D0

! Celestial body's (NTARG) Cartesian coordinates w.r.t. Center body (NCTR)
      NTARG = NTARG_body
      CALL  PLEPH ( JD, NTARG, NCTR, Zbody )
	  
! Cartesian coordinates of the celestial body in meters: KM to M
	  rbody(1) = Zbody(1) * 1000.D0
	  rbody(2) = Zbody(2) * 1000.D0
	  rbody(3) = Zbody(3) * 1000.D0

! Sun
	  rSun = rbody
	  !vSun = (/ Zbody(4), Zbody(5), Zbody(6) /) * 1000.D0 ! KM/sec to m/sec	  
! ----------------------------------------------------------------------


! ----------------------------------------------------------------------
! Satellite Attitude computation 
! ----------------------------------------------------------------------
! Yaw-attitude model
CALL attitude (mjd, rsat_icrf, vsat_icrf, rSun, PRNsat, satblk, BDSorbtype, &
                     eclipse_status, beta, Mangle, Yangle_array, eBX_nom, eBX_ecl)
! ----------------------------------------------------------------------


! ----------------------------------------------------------------------
! Rotation matrices
! ----------------------------------------------------------------------
! Rotation matrix Intertial to Body-fixed frame
Yaw_angle = Yangle_array(2)
CALL crf_bff (rsat_icrf, vsat_icrf, Yaw_angle, Rcrf_bff, Rrtn_bff)

! Inverse matrix
!Rbff2crf = inv(Rcrf_bff)
!An = size(Rcrf_bff, DIM = 2)
!Call matrixinv (Rcrf_bff, Rbff2crf, An)
CALL matrix_inv3 (Rcrf_bff, Rbff2crf)
 
! Rotation matrix: Intertial to Terrestrial frame
!CALL crs_trs (mjd, EOP_ar, iau_model, CRS2TRS, TRS2CRS, d_CRS2TRS, d_TRS2CRS)
CALL EOP (mjd, EOP_cr, CRS2TRS, TRS2CRS, d_CRS2TRS, d_TRS2CRS)	  

! Body-fixed frame to Terrestrial frame
!Rbff2trf = Rbff2crf * CRS2TRS
Rbff2trf = MATMUL(Rbff2crf,CRS2TRS)

! Rotation matrix: Terrestrial reference frame to body-fixed frame
!An = size(Rbff2trf, DIM = 2)
!Call matrixinv (Rbff2trf, Rtrf2bff, An)
CALL matrix_inv3 (Rbff2trf, Rtrf2bff)
! ----------------------------------------------------------------------

Rtrf2bff = MATMUL(TRS2CRS,Rcrf_bff)

! ----------------------------------------------------------------------
! Quaternions computation based on rotation matrix
! ----------------------------------------------------------------------
! Rotation matrix to quaternions
CALL mat2quater(Rtrf2bff,quater)
Quaternions_trf2bff = quater
! ----------------------------------------------------------------------

end
