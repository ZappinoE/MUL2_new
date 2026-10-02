!=======================================================================
!  SINGLE REGISTRY OF SUPPORTED ELEMENT TOPOLOGIES.
!=======================================================================
      MODULE MUL2_TOPOLOGIES                                             ! Module mul2 topologies begins.

      USE MUL2_KINDS, ONLY: I4                                           ! Use from module mul2 kinds: i4.
      USE MUL2_STRINGS, ONLY: UPPERCASE                                  ! Use from module mul2 strings: uppercase.
      USE MUL2_HLE_SHAPE, ONLY: HLE_FUNCTION_COUNT                       ! Use from module mul2 hle shape: hle function count.

      IMPLICIT NONE                                                      ! Every variable must be declared explicitly.
      PRIVATE                                                            ! Everything in the module is private unless exported.

      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_UNKNOWN = 0_I4          ! Constant public integer (int32): topology_unknown = 0.
      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_B2 = 101_I4             ! Constant public integer (int32): topology_b2 = 101.
      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_B3 = 102_I4             ! Constant public integer (int32): topology_b3 = 102.
      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_B4 = 103_I4             ! Constant public integer (int32): topology_b4 = 103.
      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_Q4 = 201_I4             ! Constant public integer (int32): topology_q4 = 201.
      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_Q9 = 202_I4             ! Constant public integer (int32): topology_q9 = 202.
      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_Q16 = 203_I4            ! Constant public integer (int32): topology_q16 = 203.
      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_T3 = 204_I4             ! Constant public integer (int32): topology_t3 = 204.
      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_T6 = 205_I4             ! Constant public integer (int32): topology_t6 = 205.
      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_H8 = 301_I4             ! Constant public integer (int32): topology_h8 = 301.
      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_H20 = 302_I4            ! Constant public integer (int32): topology_h20 = 302.
      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_H27 = 303_I4            ! Constant public integer (int32): topology_h27 = 303.
      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_T4 = 304_I4             ! Constant public integer (int32): topology_t4 = 304.
      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_T10 = 305_I4            ! Constant public integer (int32): topology_t10 = 305.
      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_P6 = 306_I4             ! Constant public integer (int32): topology_p6 = 306.
      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_S1 = 401_I4             ! Constant public integer (int32): topology_s1 = 401.
!  HLE SUB-ELEMENTS: BASE + POLYNOMIAL ORDER P (1..99). THE BASE VALUE
!  ITSELF IS THE FAMILY NAME BEFORE THE ORDER IS KNOWN.
      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_HB_BASE = 1100_I4       ! Constant public integer (int32): topology_hb_base = 1100.
      INTEGER(I4), PARAMETER, PUBLIC :: TOPOLOGY_HQ_BASE = 2100_I4       ! Constant public integer (int32): topology_hq_base = 2100.

      PUBLIC :: TOPOLOGY_FROM_NAME                                       ! Export: topology from name.
      PUBLIC :: TOPOLOGY_NODE_COUNT                                      ! Export: topology node count.
      PUBLIC :: TOPOLOGY_NATURAL_DIMENSION                               ! Export: topology natural dimension.
      PUBLIC :: TOPOLOGY_FUNCTION_COUNT                                  ! Export: topology function count.
      PUBLIC :: TOPOLOGY_IS_HLE                                          ! Export: topology is hle.
      PUBLIC :: TOPOLOGY_HLE_ORDER                                       ! Export: topology hle order.
      PUBLIC :: TOPOLOGY_IS_HLE_FAMILY                                   ! Export: topology is hle family.

      CONTAINS                                                           ! The procedures of the module follow.

      INTEGER(I4) FUNCTION TOPOLOGY_FROM_NAME(NAME)                      ! Function topology from name takes name.

      CHARACTER(LEN=*), INTENT(IN) :: NAME                               ! Input character (length *): name.
      CHARACTER(LEN=16) :: CLEAN                                         ! Character (length 16): clean.

      CLEAN = NAME                                                       ! Set clean to name.
      CALL UPPERCASE(CLEAN)                                              ! Call uppercase with clean.
      SELECT CASE (TRIM(ADJUSTL(CLEAN)))                                 ! Choose according to the value of trim(adjustl(clean)):
      CASE ('B2')                                                        ! Case 'B2':
        TOPOLOGY_FROM_NAME = TOPOLOGY_B2                                 ! Set topology_from_name to topology_b2.
      CASE ('B3')                                                        ! Case 'B3':
        TOPOLOGY_FROM_NAME = TOPOLOGY_B3                                 ! Set topology_from_name to topology_b3.
      CASE ('B4')                                                        ! Case 'B4':
        TOPOLOGY_FROM_NAME = TOPOLOGY_B4                                 ! Set topology_from_name to topology_b4.
      CASE ('Q4')                                                        ! Case 'Q4':
        TOPOLOGY_FROM_NAME = TOPOLOGY_Q4                                 ! Set topology_from_name to topology_q4.
      CASE ('Q9')                                                        ! Case 'Q9':
        TOPOLOGY_FROM_NAME = TOPOLOGY_Q9                                 ! Set topology_from_name to topology_q9.
      CASE ('Q16')                                                       ! Case 'Q16':
        TOPOLOGY_FROM_NAME = TOPOLOGY_Q16                                ! Set topology_from_name to topology_q16.
      CASE ('Q3','T3')                                                   ! Case 'Q3','T3':
        TOPOLOGY_FROM_NAME = TOPOLOGY_T3                                 ! Set topology_from_name to topology_t3.
      CASE ('Q6','T6')                                                   ! Case 'Q6','T6':
        TOPOLOGY_FROM_NAME = TOPOLOGY_T6                                 ! Set topology_from_name to topology_t6.
      CASE ('H8')                                                        ! Case 'H8':
        TOPOLOGY_FROM_NAME = TOPOLOGY_H8                                 ! Set topology_from_name to topology_h8.
      CASE ('H20')                                                       ! Case 'H20':
        TOPOLOGY_FROM_NAME = TOPOLOGY_H20                                ! Set topology_from_name to topology_h20.
      CASE ('H27')                                                       ! Case 'H27':
        TOPOLOGY_FROM_NAME = TOPOLOGY_H27                                ! Set topology_from_name to topology_h27.
      CASE ('T4')                                                        ! Case 'T4':
        TOPOLOGY_FROM_NAME = TOPOLOGY_T4                                 ! Set topology_from_name to topology_t4.
      CASE ('T10')                                                       ! Case 'T10':
        TOPOLOGY_FROM_NAME = TOPOLOGY_T10                                ! Set topology_from_name to topology_t10.
      CASE ('P6')                                                        ! Case 'P6':
        TOPOLOGY_FROM_NAME = TOPOLOGY_P6                                 ! Set topology_from_name to topology_p6.
      CASE ('S1')                                                        ! Case 'S1':
        TOPOLOGY_FROM_NAME = TOPOLOGY_S1                                 ! Set topology_from_name to topology_s1.
      CASE ('HB2','HB')                                                  ! Case 'HB2','HB':
        TOPOLOGY_FROM_NAME = TOPOLOGY_HB_BASE                            ! Set topology_from_name to topology_hb_base.
      CASE ('HQ4','HQ')                                                  ! Case 'HQ4','HQ':
        TOPOLOGY_FROM_NAME = TOPOLOGY_HQ_BASE                            ! Set topology_from_name to topology_hq_base.
      CASE DEFAULT                                                       ! In every other case:
        TOPOLOGY_FROM_NAME = TOPOLOGY_UNKNOWN                            ! Set topology_from_name to topology_unknown.
      END SELECT                                                         ! End of the case selection.

      END FUNCTION TOPOLOGY_FROM_NAME                                    ! End of the function topology from name.

      INTEGER(I4) FUNCTION TOPOLOGY_NODE_COUNT(TOPOLOGY)                 ! Function topology node count takes topology.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.

      SELECT CASE (TOPOLOGY)                                             ! Choose according to the value of topology:
      CASE (TOPOLOGY_S1)                                                 ! Case topology_s1:
        TOPOLOGY_NODE_COUNT = 1_I4                                       ! Set topology_node_count to 1.
      CASE (TOPOLOGY_B2, TOPOLOGY_HB_BASE:TOPOLOGY_HB_BASE+99_I4)        ! Case topology_b2, topology_hb_base:topology_hb_base+99:
        TOPOLOGY_NODE_COUNT = 2_I4                                       ! Set topology_node_count to 2.
      CASE (TOPOLOGY_B3,TOPOLOGY_T3)                                     ! Case topology_b3,topology_t3:
        TOPOLOGY_NODE_COUNT = 3_I4                                       ! Set topology_node_count to 3.
      CASE (TOPOLOGY_B4,TOPOLOGY_Q4,TOPOLOGY_T4,                         ! Case topology_b4,topology_q4,topology_t4, topology_hq_base:topology_hq_base+99:
     &      TOPOLOGY_HQ_BASE:TOPOLOGY_HQ_BASE+99_I4)
        TOPOLOGY_NODE_COUNT = 4_I4                                       ! Set topology_node_count to 4.
      CASE (TOPOLOGY_T6,TOPOLOGY_P6)                                     ! Case topology_t6,topology_p6:
        TOPOLOGY_NODE_COUNT = 6_I4                                       ! Set topology_node_count to 6.
      CASE (TOPOLOGY_H8)                                                 ! Case topology_h8:
        TOPOLOGY_NODE_COUNT = 8_I4                                       ! Set topology_node_count to 8.
      CASE (TOPOLOGY_Q9)                                                 ! Case topology_q9:
        TOPOLOGY_NODE_COUNT = 9_I4                                       ! Set topology_node_count to 9.
      CASE (TOPOLOGY_T10)                                                ! Case topology_t10:
        TOPOLOGY_NODE_COUNT = 10_I4                                      ! Set topology_node_count to 10.
      CASE (TOPOLOGY_Q16)                                                ! Case topology_q16:
        TOPOLOGY_NODE_COUNT = 16_I4                                      ! Set topology_node_count to 16.
      CASE (TOPOLOGY_H20)                                                ! Case topology_h20:
        TOPOLOGY_NODE_COUNT = 20_I4                                      ! Set topology_node_count to 20.
      CASE (TOPOLOGY_H27)                                                ! Case topology_h27:
        TOPOLOGY_NODE_COUNT = 27_I4                                      ! Set topology_node_count to 27.
      CASE DEFAULT                                                       ! In every other case:
        TOPOLOGY_NODE_COUNT = 0_I4                                       ! Set topology_node_count to zero.
      END SELECT                                                         ! End of the case selection.

      END FUNCTION TOPOLOGY_NODE_COUNT                                   ! End of the function topology node count.

      INTEGER(I4) FUNCTION TOPOLOGY_NATURAL_DIMENSION(TOPOLOGY)          ! Function topology natural dimension takes topology.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.

      SELECT CASE (TOPOLOGY)                                             ! Choose according to the value of topology:
      CASE (TOPOLOGY_S1)                                                 ! Case topology_s1:
        TOPOLOGY_NATURAL_DIMENSION = 0_I4                                ! Set topology_natural_dimension to zero.
      CASE (TOPOLOGY_B2,TOPOLOGY_B3,TOPOLOGY_B4,                         ! Case topology_b2,topology_b3,topology_b4, topology_hb_base:topology_hb_base+99:
     &      TOPOLOGY_HB_BASE:TOPOLOGY_HB_BASE+99_I4)
        TOPOLOGY_NATURAL_DIMENSION = 1_I4                                ! Set topology_natural_dimension to 1.
      CASE (TOPOLOGY_Q4,TOPOLOGY_Q9,TOPOLOGY_Q16,                        ! Case topology_q4,topology_q9,topology_q16, topology_t3,topology_t6, topology_hq_base:topology_hq_base+99:
     &      TOPOLOGY_T3,TOPOLOGY_T6,
     &      TOPOLOGY_HQ_BASE:TOPOLOGY_HQ_BASE+99_I4)
        TOPOLOGY_NATURAL_DIMENSION = 2_I4                                ! Set topology_natural_dimension to 2.
      CASE (TOPOLOGY_H8,TOPOLOGY_H20,TOPOLOGY_H27,                       ! Case topology_h8,topology_h20,topology_h27, topology_t4,topology_t10,topology_p6:
     &      TOPOLOGY_T4,TOPOLOGY_T10,TOPOLOGY_P6)
        TOPOLOGY_NATURAL_DIMENSION = 3_I4                                ! Set topology_natural_dimension to 3.
      CASE DEFAULT                                                       ! In every other case:
        TOPOLOGY_NATURAL_DIMENSION = 0_I4                                ! Set topology_natural_dimension to zero.
      END SELECT                                                         ! End of the case selection.

      END FUNCTION TOPOLOGY_NATURAL_DIMENSION                            ! End of the function topology natural dimension.

!  NUMBER OF SHAPE FUNCTIONS (NODES FOR LAGRANGE ELEMENTS, MODES FOR
!  HLE SUB-ELEMENTS).
      INTEGER(I4) FUNCTION TOPOLOGY_FUNCTION_COUNT(TOPOLOGY)             ! Function topology function count takes topology.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.

      IF (TOPOLOGY_IS_HLE(TOPOLOGY)) THEN                                ! If topology_is_hle(topology):
        TOPOLOGY_FUNCTION_COUNT = HLE_FUNCTION_COUNT(                    ! Set topology_function_count to hle_function_count( topology > topology_hq_base, topology_hle_order(topology)).
     &    TOPOLOGY .GT. TOPOLOGY_HQ_BASE, TOPOLOGY_HLE_ORDER(TOPOLOGY))
      ELSE                                                               ! Otherwise:
        TOPOLOGY_FUNCTION_COUNT = TOPOLOGY_NODE_COUNT(TOPOLOGY)          ! Set topology_function_count to topology_node_count(topology).
      END IF                                                             ! End of the IF block.

      END FUNCTION TOPOLOGY_FUNCTION_COUNT                               ! End of the function topology function count.

!  TRUE FOR A HLE SUB-ELEMENT OF A DEFINED ORDER.
      LOGICAL FUNCTION TOPOLOGY_IS_HLE(TOPOLOGY)                         ! Function topology is hle takes topology.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.

      TOPOLOGY_IS_HLE = TOPOLOGY .GT. TOPOLOGY_HB_BASE .AND.             ! Set topology_is_hle to topology > topology_hb_base and topology <= topology_hb_base+99.
     &                  TOPOLOGY .LE. TOPOLOGY_HB_BASE+99_I4
      IF (TOPOLOGY .GT. TOPOLOGY_HQ_BASE .AND.                           ! If topology > topology_hq_base and topology <= topology_hq_base+99, set the flag topology_is_hle to true.
     &    TOPOLOGY .LE. TOPOLOGY_HQ_BASE+99_I4)
     &  TOPOLOGY_IS_HLE = .TRUE.

      END FUNCTION TOPOLOGY_IS_HLE                                       ! End of the function topology is hle.

!  TRUE FOR THE FAMILY NAME ALONE (ORDER NOT YET READ).
      LOGICAL FUNCTION TOPOLOGY_IS_HLE_FAMILY(TOPOLOGY)                  ! Function topology is hle family takes topology.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.

      TOPOLOGY_IS_HLE_FAMILY = TOPOLOGY .EQ. TOPOLOGY_HB_BASE .OR.       ! Set topology_is_hle_family to topology = topology_hb_base or topology = topology_hq_base.
     &                         TOPOLOGY .EQ. TOPOLOGY_HQ_BASE

      END FUNCTION TOPOLOGY_IS_HLE_FAMILY                                ! End of the function topology is hle family.

      INTEGER(I4) FUNCTION TOPOLOGY_HLE_ORDER(TOPOLOGY)                  ! Function topology hle order takes topology.

      INTEGER(I4), INTENT(IN) :: TOPOLOGY                                ! Input integer (int32): topology.

      TOPOLOGY_HLE_ORDER = 0_I4                                          ! Set topology_hle_order to zero.
      IF (TOPOLOGY_IS_HLE(TOPOLOGY))                                     ! If topology_is_hle(topology), set topology_hle_order to mod(topology,100).
     &  TOPOLOGY_HLE_ORDER = MOD(TOPOLOGY,100_I4)

      END FUNCTION TOPOLOGY_HLE_ORDER                                    ! End of the function topology hle order.

      END MODULE MUL2_TOPOLOGIES                                         ! End of the module mul2 topologies.
