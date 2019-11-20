MODULE m_clock_read


! ----------------------------------------------------------------------
! MODULE: m_clock_read.f03
! ----------------------------------------------------------------------
! Purpose:
!  Module for calling the subroutine 'clock_read' for reading GNSS orbits in sp3 format
! ----------------------------------------------------------------------
! Author :	Dr. Thomas Papanikolaou at Geoscience Australia
! Created:	18 October 2018
! ----------------------------------------------------------------------


      IMPLICIT NONE
      !SAVE 			
	  


Contains


SUBROUTINE clock_read (CLKfname,CLKformat, PRNmatrix, CLKmatrix)

! ----------------------------------------------------------------------
! SUBROUTINE: clock_read
! ----------------------------------------------------------------------
! Purpose:
!  Read clock data file format for forming a 3-dimensions clocks matrix for all satellites
! ----------------------------------------------------------------------
! Input arguments:
! - CLKfname:		GNSS satellite clocks file name 
! - CLKformat:		GNSS satellite clocks file format
! 					0. Return zero matrix for clocks output array (CLKmatrix)
! 					1. sp3 format
! 					2. clk format 
! - PRNmatrix:      Satellites' PRN numbers allocatable array
!
! Output allocatable arrays:
! - CLKmatrix:		Clocks dynamic allocatable array (3-dimensional)
!					CLKmatrix(i,j,isat) = [MJD Sec_of_day clock]
!					If clock error (sdev) is available (when Position and Velocity vector are written in orbit sp3 format)
!					CLKmatrix(i,j,isat) = [MJD Sec_of_day clock clock_sdev]
! ----------------------------------------------------------------------
! Author :	Dr. Thomas Papanikolaou at Geoscience Australia
! Created:	18 October 2018
! ----------------------------------------------------------------------

      USE mdl_precision
      USE mdl_num
      USE m_sp3
      IMPLICIT NONE
	  
! ----------------------------------------------------------------------
! Dummy arguments declaration
! ----------------------------------------------------------------------
! IN
      CHARACTER (LEN=300), INTENT(IN) :: CLKfname
      INTEGER (KIND = prec_int2), INTENT(IN) :: CLKformat
      CHARACTER (LEN=3), INTENT(IN), ALLOCATABLE :: PRNmatrix(:)

! OUT
      REAL (KIND = prec_q), INTENT(OUT), DIMENSION(:,:,:), ALLOCATABLE :: CLKmatrix
! ----------------------------------------------------------------------

! ----------------------------------------------------------------------
! Local variables declaration
! ----------------------------------------------------------------------
      INTEGER (KIND = prec_int8) :: Nsat, isat, Nepochs, Nel  
      CHARACTER (LEN=3) :: PRNid
      REAL (KIND = prec_q), DIMENSION(:,:), ALLOCATABLE :: orbsp3, clock_matrix
      INTEGER (KIND = prec_int2) :: AllocateStatus
! ----------------------------------------------------------------------


! PRN array dimensions
Nsat = SIZE (PRNmatrix,DIM=1)

IF (CLKformat == 0) THEN
	ALLOCATE (CLKmatrix(1,1,1), STAT = AllocateStatus)
	CLKmatrix = 0.0D0  
! ----------------------------------------------------------------------
ELSE IF (CLKformat == 1) THEN	  
	DO isat = 1 , Nsat
		PRNid = PRNmatrix(isat)
		CALL sp3(CLKfname,PRNid,orbsp3,clock_matrix)
		IF (isat==1) THEN
		! Clock array dimensions
		Nepochs = SIZE (clock_matrix,DIM=1)
		Nel     = SIZE (clock_matrix,DIM=2)
		! Allocate array
		ALLOCATE (CLKmatrix(Nepochs,Nel,Nsat), STAT = AllocateStatus)
		END IF
		CLKmatrix (:,:,isat) = clock_matrix
	END DO
! ----------------------------------------------------------------------
!ELSE IF (CLKformat == 2) THEN	  
!
END IF	  
! ----------------------------------------------------------------------

END SUBROUTINE

End Module


