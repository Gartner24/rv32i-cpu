SRC := ..
IV  := iverilog
VVP := vvp

UNIT_TESTS := adder mux2to1 alu alu_control control_unit imm_gen pc register_file data_memory hex_display
ALL_TESTS  := $(UNIT_TESTS) top

.PHONY: all $(addprefix test_,$(ALL_TESTS)) clean

all: $(addprefix test_,$(ALL_TESTS))
	@echo ""
	@echo "--- All tests complete ---"

waves:
	mkdir -p waves

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

# ---------- integration test ----------

TOP_SRCS := $(SRC)/mux2to1.v $(SRC)/adder.v $(SRC)/alu.v $(SRC)/imm_gen.v \
            $(SRC)/register_file.v $(SRC)/alu_control.v $(SRC)/control_unit.v \
            $(SRC)/instruction_memory.v $(SRC)/data_memory.v $(SRC)/pc.v \
            $(SRC)/hex_display.v $(SRC)/top.v

test_top: waves top_tb.v program.hex $(TOP_SRCS)
	@$(IV) -o waves/top_tb.vvp top_tb.v $(TOP_SRCS) && $(VVP) waves/top_tb.vvp

clean:
	rm -rf waves
