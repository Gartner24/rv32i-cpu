SRC := ..
IV  := iverilog
VVP := vvp

UNIT_TESTS := adder mux2to1 alu alu_control control_unit imm_gen pc register_file data_memory hex_display
ALL_TESTS  := $(UNIT_TESTS) top final_test

.PHONY: all $(addprefix test_,$(ALL_TESTS)) clean

all: $(addprefix test_,$(ALL_TESTS))
	@echo ""
	@echo "--- All tests complete ---"

waves:
	mkdir -p waves

font128.hex:
	ln -sf ../font128.hex font128.hex

# ---------- unit tests ----------

test_adder: waves adder_tb.v $(SRC)/adder.v
	@$(IV) -o waves/adder_tb.vvp adder_tb.v $(SRC)/adder.v && $(VVP) waves/adder_tb.vvp

test_mux2to1: waves mux2to1_tb.v $(SRC)/mux2to1.v
	@$(IV) -o waves/mux2to1_tb.vvp mux2to1_tb.v $(SRC)/mux2to1.v && $(VVP) waves/mux2to1_tb.vvp

test_alu: waves alu_tb.v $(SRC)/alu.v
	@$(IV) -o waves/alu_tb.vvp alu_tb.v $(SRC)/alu.v && $(VVP) waves/alu_tb.vvp

test_alu_control: waves alu_control_tb.v $(SRC)/alu_control.v
	@$(IV) -o waves/alu_control_tb.vvp alu_control_tb.v $(SRC)/alu_control.v && $(VVP) waves/alu_control_tb.vvp

test_control_unit: waves control_unit_tb.v $(SRC)/control_unit.v
	@$(IV) -o waves/control_unit_tb.vvp control_unit_tb.v $(SRC)/control_unit.v && $(VVP) waves/control_unit_tb.vvp

test_imm_gen: waves imm_gen_tb.v $(SRC)/imm_gen.v
	@$(IV) -o waves/imm_gen_tb.vvp imm_gen_tb.v $(SRC)/imm_gen.v && $(VVP) waves/imm_gen_tb.vvp

test_pc: waves pc_tb.v $(SRC)/pc.v
	@$(IV) -o waves/pc_tb.vvp pc_tb.v $(SRC)/pc.v && $(VVP) waves/pc_tb.vvp

test_register_file: waves register_file_tb.v $(SRC)/register_file.v
	@$(IV) -o waves/register_file_tb.vvp register_file_tb.v $(SRC)/register_file.v && $(VVP) waves/register_file_tb.vvp

test_data_memory: waves data_memory_tb.v $(SRC)/data_memory.v
	@$(IV) -o waves/data_memory_tb.vvp data_memory_tb.v $(SRC)/data_memory.v && $(VVP) waves/data_memory_tb.vvp

test_hex_display: waves hex_display_tb.v $(SRC)/hex_display.v
	@$(IV) -o waves/hex_display_tb.vvp hex_display_tb.v $(SRC)/hex_display.v && $(VVP) waves/hex_display_tb.vvp

# ---------- integration tests ----------

TOP_SRCS := $(SRC)/mux2to1.v $(SRC)/adder.v $(SRC)/alu.v $(SRC)/imm_gen.v \
            $(SRC)/register_file.v $(SRC)/alu_control.v $(SRC)/control_unit.v \
            $(SRC)/instruction_memory.v $(SRC)/data_memory.v $(SRC)/pc.v \
            $(SRC)/hex_display.v $(SRC)/clock_div.v $(SRC)/vga_controller.v \
            $(SRC)/forwarding_unit.v $(SRC)/hazard_unit.v \
            $(SRC)/pipe_ifid.v $(SRC)/pipe_idex.v \
            $(SRC)/pipe_exmem.v $(SRC)/pipe_memwb.v \
            $(SRC)/vga_debug.v $(SRC)/top.v

test_top: waves font128.hex top_tb.v program.hex $(TOP_SRCS)
	@$(IV) -o waves/top_tb.vvp top_tb.v $(TOP_SRCS) && $(VVP) waves/top_tb.vvp

test_final_test: waves font128.hex top_final_test_tb.v $(TOP_SRCS)
	@$(IV) -o waves/top_final_test_tb.vvp top_final_test_tb.v $(TOP_SRCS) && $(VVP) waves/top_final_test_tb.vvp

test_pipe_smoke: waves font128.hex pipe_smoke_tb.v pipe_smoke.hex $(TOP_SRCS)
	@$(IV) -o waves/pipe_smoke_tb.vvp pipe_smoke_tb.v $(TOP_SRCS) && $(VVP) waves/pipe_smoke_tb.vvp

test_pipe_forward: waves font128.hex pipe_forward_tb.v pipe_forward.hex $(TOP_SRCS)
	@$(IV) -o waves/pipe_forward_tb.vvp pipe_forward_tb.v $(TOP_SRCS) && $(VVP) waves/pipe_forward_tb.vvp

test_pipe_hazard: waves font128.hex pipe_hazard_tb.v pipe_hazard.hex $(TOP_SRCS)
	@$(IV) -o waves/pipe_hazard_tb.vvp pipe_hazard_tb.v $(TOP_SRCS) && $(VVP) waves/pipe_hazard_tb.vvp

test_pipe_lui: waves font128.hex pipe_lui_tb.v pipe_lui.hex $(TOP_SRCS)
	@$(IV) -o waves/pipe_lui_tb.vvp pipe_lui_tb.v $(TOP_SRCS) && $(VVP) waves/pipe_lui_tb.vvp

# ---------- programas reales del ensamblador (../../assembler/*.hex) ----------
# Cada uno corre hasta halt y verifica x10==0 (main devuelve 0 si todo pasa).
ASM := ../../assembler

define run_program
	@$(IV) -Pprogram_test_tb.HEXF='"$(ASM)/$(1).hex"' \
	    -o waves/prog_$(1).vvp program_test_tb.v $(TOP_SRCS) && $(VVP) waves/prog_$(1).vvp
endef

test_arith: waves font128.hex program_test_tb.v $(TOP_SRCS)
	$(call run_program,test_arith)

test_bits: waves font128.hex program_test_tb.v $(TOP_SRCS)
	$(call run_program,test_bits)

test_loops: waves font128.hex program_test_tb.v $(TOP_SRCS)
	$(call run_program,test_loops)

test_memory: waves font128.hex program_test_tb.v $(TOP_SRCS)
	$(call run_program,test_memory)

test_newfinal: waves font128.hex program_test_tb.v $(TOP_SRCS)
	$(call run_program,new_final_test)

# Corre todos los programas reales y los testbenches de pipeline.
programs: test_arith test_bits test_loops test_memory test_newfinal \
          test_pipe_smoke test_pipe_forward test_pipe_hazard test_pipe_lui
	@echo ""
	@echo "--- All program tests complete ---"

clean:
	rm -rf waves font128.hex
