# Julia script for unit commitment problem
# The original problem was written in AMPL scripts,
# which were provided by Changhyeok Lee
# Kibaek Kim - 2015 ANL MCS


# NOTE:
#   - Construct model in a local scope and feed it to DSP solver.
#   - This allows garbage collection to free memory.

let

# ---------------
# Read data files
# ---------------

tmpdat1 = readdlm("IEEE118/generator.dat", '\t');
tmpdat2 = readdlm("IEEE118/generator_cost_function.dat", '\t');
tmpdat3 = readdlm("IEEE118/load_profile.dat", '\t');
tmpdat4 = readdlm("IEEE118/load_distribution.dat", '\t');
tmpdat5 = readdlm("IEEE118/wind_profile.dat", '\t');
tmpdat6 = readdlm("IEEE118/wind_distribution.dat", '\t');
tmpdat7 = readdlm("IEEE118/shift_factor.dat", '\t');
tmpdat8 = readdlm("IEEE118/branch.dat", '\t');

# -----------------
# Parameter setting
# -----------------

if isdefined(:nScenarios) == false
	nScenarios  = 3;
end
nBuses      = 118;
nBranches   = 186;
nGenerators = 54;
nWinds      = 3;
nPeriods    = 24;
nSegments   = 4;

BUSES      = 1:nBuses;
BRANCHES   = 1:nBranches;
GENERATORS = 1:nGenerators;
WINDS      = 1:nWinds;
PERIODS    = 1:nPeriods;
SEGMENTS   = 1:nSegments;

prob = ones(nScenarios) / nScenarios; # probabilities

#tmpdat1[:,1];                  # Index
gen_bus_id     = tmpdat1[:,2];  # Bus ID, where generators are attached
min_gen        = tmpdat1[:,3];  # Minimum power generation (MW)
max_gen        = tmpdat1[:,4];  # Maximum power generation (MW)
gen_0          = tmpdat1[:,5];  # Power generation in hour 0 (MW)
use_history    = tmpdat1[:,6];  # number of hours the generator has been on or off before hour 1
uptime         = tmpdat1[:,7];  # Minimum uptime (hours)
downtime       = tmpdat1[:,8];  # Minimum downtime (hours)
ramp_rate      = tmpdat1[:,9];  # Ramp rate per hour (MW/hour)
# tmpdat1[:,10];                # Ramp down
# tmpdat1[:,11];                # MSR
# tmpdat1[:,12];                # Quick start capability?
fixed_cost_gen = tmpdat1[:,13]; # Fixed cost of running the generator for an hour ($)
cost_start     = tmpdat1[:,14]; # Cost of starting a generator ($)
# tmpdat1[:,15];                # Some cost?
# tmpdat1[:,16];                # Some cost?

cost_gen     = tmpdat2[:,1:4]; # Marginal cost of production ($/MWh)
max_gen_sgmt = tmpdat2[:,5:8]; # Length of each power output segment (MW)

spin_resv_rate = 0.04; # Spinning reserve percentage
spin_notice    = 10;   # Spinning notice window (min)

total_demand = tmpdat3[:,1]; # Power load for each hour (MW)
demand_dist = zeros(nBuses); # Demand distribution
for i in 1:size(tmpdat4,1)
	demand_dist[tmpdat4[i,2]] = tmpdat4[i,3];
end

total_wind  = tmpdat5[:,1]; # Total wind power generation for each hour (MW)
wind_bus_id = tmpdat6[:,2]; # Wind power generator ID
wind_dist   = tmpdat6[:,3]; # Wind power distribution

# Load shift factor (This is pre-computed using branch_from_bus and branch_to_bus.)
load_shift_factor = tmpdat7';
flow_max          = tmpdat8[:,8]; # Transmission line capacity

# -------------------------------
# Initialize auxiliary parameters
# -------------------------------

use_0         = zeros(nGenerators);      # Unit commitment in hour 0
downtime_init = zeros(nGenerators);      # Initial minimum downtime
uptime_init   = zeros(nGenerators);      # Initial minimum uptime
demand        = zeros(nBuses, nPeriods); # Power load
wind          = zeros(nWinds, nPeriods); # Wind power generation

for i in GENERATORS
	if use_history[i] > 0
		use_0[i] = 1;
	else
		use_0[i] = 0;
	end
	downtime_init[i] = max(0, downtime[i] + use_history[i]) * (1 - use_0[i]);
	uptime_init[i]   = max(0, uptime[i] - use_history[i]) * use_0[i];
end

for t in PERIODS
	for n in BUSES
		demand[n,t] = demand_dist[n] / sum(demand_dist) * total_demand[t];
	end
	for n in WINDS
		wind[n,t] = wind_dist[n] / sum(wind_dist) * total_wind[t];
	end
end

# -------------------
# Scenario generation
# -------------------

srand(1);
load_uncertainty = 0.03; # Load uncertainty
wind_uncertainty = 0.55;  # Wind power generation uncertainty

# Load scenarios
total_demand_scen = zeros(nPeriods, nScenarios);
demand_scen = zeros(nBuses, nPeriods, nScenarios);
total_demand_scen[:,1] = total_demand;
#demand_scen[:,:,1]     = demand;
for s in 1:nScenarios
	total_demand_scen[:,s] = total_demand * (1 - load_uncertainty) + rand(nPeriods) .* total_demand * load_uncertainty * 2;
	demand_scen[:,:,s] = demand_dist ./ sum(demand_dist) * total_demand_scen[:,s]';
end

# Wind power scenarios
wind_scen = zeros(nWinds, nPeriods, nScenarios);
#wind_scen[:,:,1] = wind;
for s in 1:nScenarios
	wind_scen[:,:,s] = wind * (1 - wind_uncertainty) + rand(nWinds, nPeriods) .* wind * wind_uncertainty * 2;
end
total_wind_scen = reshape(sum(wind_scen,1), nPeriods, nScenarios);

# -----------------
# Release file data
# -----------------

tmpdat1 = 0;
tmpdat2 = 0;
tmpdat3 = 0;
tmpdat4 = 0;
tmpdat5 = 0;
tmpdat6 = 0;
tmpdat7 = 0;
tmpdat8 = 0;

# ----------------
# StochJuMP object
# ----------------
m = StochasticModel(nScenarios);

# ------------------------------------------------------
# The following parameters need to be defined with data.
# ------------------------------------------------------
# BUSES
# BRANCHES
# GENERATORS
# WINDS
# PERIODS
# SEGMENTS
# gen_bus_id       [GENERATORS]
# cost_start       [GENERATORS]
# fixed_cost_gen   [GENERATORS]
# cost_gen         [GENERATORS, SEGMENTS]
# use_history      [GENERATORS]
# downtime         [GENERATORS]
# uptime           [GENERATORS]
# use_0            [GENERATORS]
# downtime_init    [GENERATORS]
# uptime_init      [GENERATORS]
# min_gen          [GENERATORS]
# max_gen          [GENERATORS]
# max_gen_sgmt     [GENERATORS, SEGMENTS]
# ramp_rate        [GENERATORS]
# gen_0            [GENERATORS]
# spin_resv_rate
# spin_notice
# total_demand     [PERIODS]
# demand           [BUSES,PERIODS]
# wind_bus_id      [WINDS]
# total_wind       [PERIODS]
# wind             [WINDS,PERIODS]
# flow_max         [BRANCHES]
# load_shift_factor[BUSES, BRANCHES]

# ---------------------
# First-stage Variables
# ---------------------
@defVar(m, Use[i=GENERATORS, t=PERIODS], Bin)       # Generator on/off indicator
@defVar(m, 0 <= Up[i=GENERATORS, t=PERIODS] <= 1)   # Start up indicator
@defVar(m, 0 <= Down[i=GENERATORS, t=PERIODS] <= 1) # Shut down indicator

# ------------------------------
# First-stage Objective function
# ------------------------------
@setObjective(m, Min,
	sum{cost_start[i] * Up[i,t], i=GENERATORS, t=PERIODS}
	+ sum{fixed_cost_gen[i] * Use[i,t], i=GENERATORS, t=PERIODS})

# -----------------------
# First-stage Constraints
# -----------------------

# Linking Use / Up / Down variables
@addConstraint(m, LINKING_SHUT_DOWN0[i=GENERATORS],
	Down[i,1] <= use_0[i])
@addConstraint(m, LINKING_SHUT_DOWN[i=GENERATORS, t=2:nPeriods],
	Use[i,t-1] >= Down[i,t])
@addConstraint(m, LINKING_START_UP0[i=GENERATORS],
	Up[i,1] <= 1 - use_0[i])
@addConstraint(m, LINKING_START_UP[i=GENERATORS, t=2:nPeriods],
	1 - Use[i,t-1] >= Up[i,t])
@addConstraint(m, LINKING_BOTH0[i=GENERATORS],
	Use[i,1] - use_0[i] == Up[i,1] - Down[i,1])
@addConstraint(m, LINKING_BOTH[i=GENERATORS, t=2:nPeriods],
	Use[i,t] - Use[i,t-1] == Up[i,t] - Down[i,t])

# Min down time
@addConstraint(m, MIN_DOWN_INIT[i=GENERATORS, t=1:min(downtime_init[i],nPeriods)],
	Use[i,t] == 0)
@addConstraint(m, MIN_DOWN_S1[i=GENERATORS, t=PERIODS, s=max(1,t-downtime[i]+1):t],
	1 - Use[i,t] >= Down[i,s])
@addConstraint(m, MIN_DOWN_S2[i=GENERATORS, t=PERIODS],
	1 - Use[i,t] >= sum{Down[i,s], s=max(1,t-downtime[i]+1):t})

# Min up time
@addConstraint(m, MIN_UP_INIT[i=GENERATORS, t=1:min(uptime_init[i],nPeriods)],
	Use[i,t] == 1)
@addConstraint(m, MIN_UP_S1[i=GENERATORS, t=PERIODS, s=max(1,t-uptime[i]+1):t],
	Use[i,t] >= Up[i,s])
@addConstraint(m, MIN_UP_S2[i=GENERATORS, t=PERIODS],
	Use[i,t] >= sum{Up[i,s], s=max(1,t-uptime[i]+1):t})

# -----------------
# For each scenario
# -----------------
for s in 1:nScenarios

	# ----------------
	# Stochastic block
	# ----------------
	sb = StochasticBlock(m, prob[s])

	# ----------------------
	# Second-stage Variables
	# ----------------------

	@defVar(sb, 0 <= Gen[i=GENERATORS, t=PERIODS] <= max_gen[i])       # Power generation
	@defVar(sb, 0 <= Gen_Sgmt[i=GENERATORS, k=SEGMENTS, t=PERIODS] <= max_gen_sgmt[i,k])
	@defVar(sb, 0 <= Spin_Resv[i=GENERATORS, t=PERIODS] <= spin_notice / 60. * ramp_rate[i]) # Spinning reserve

	# -------------------------------
	# Second-stage Objective function
	# -------------------------------

	@setObjective(sb, Min,
		sum{cost_gen[i,k] * Gen_Sgmt[i,k,t], i=GENERATORS, k=SEGMENTS, t=PERIODS})

	# ------------------------
	# Second-stage Constraints
	# ------------------------

	# Ramping rate in normal operating status
	@addConstraint(sb, RAMP_DOWN0[i=GENERATORS],
		gen_0[i] - Gen[i,1] <= ramp_rate[i])
	@addConstraint(sb, RAMP_DOWN[i=GENERATORS, t=2:nPeriods],
		Gen[i,t-1] - Gen[i,t] <= ramp_rate[i])
	@addConstraint(sb, RAMP_UP0[i=GENERATORS],
		Gen[i,1] - gen_0[i] + Spin_Resv[i,1] <= ramp_rate[i])
	@addConstraint(sb, RAMP_UP[i=GENERATORS, t=2:nPeriods],
		Gen[i,t] - Gen[i,t-1] + Spin_Resv[i,t] <= ramp_rate[i])

	# Spinning reserve requirement for system
	@addConstraint(sb, SPIN_RESV_REQ[t=PERIODS],
		sum{Spin_Resv[i,t], i=GENERATORS}
		>= spin_resv_rate * (total_demand_scen[t,s] - total_wind_scen[t,s]))

	# Spinning reserve capacity for individual unit
	@addConstraint(sb, SPIN_RESV_MAX[i=GENERATORS, t=PERIODS],
		Spin_Resv[i,t] <= spin_notice / 60. * ramp_rate[i] * Use[i,t])

	# Power output capacity constraints
	@addConstraint(sb, POWER_OUTPUT[i=GENERATORS, t=PERIODS],
		Gen[i,t] == min_gen[i] * Use[i,t] + sum{Gen_Sgmt[i,k,t], k=SEGMENTS})
	@addConstraint(sb, POWER_SEGMENT[i=GENERATORS, k=SEGMENTS, t=PERIODS],
		Gen_Sgmt[i,k,t] <= max_gen_sgmt[i,k] * Use[i,t])
	@addConstraint(sb, POWER_MAX[i=GENERATORS, t=PERIODS],
		Gen[i,t] + Spin_Resv[i,t] <= max_gen[i] * Use[i,t])

	# Power balance constraints for system
	@addConstraint(sb, POWER_BALANCE[t=PERIODS],
		sum{Gen[i,t], i=GENERATORS} == total_demand_scen[t,s] - total_wind_scen[t,s])

	# Transmission constraints with load shift factor (These can be lazy constraints.)
	@addConstraint(sb, FLOW_BRANCH_LSF_LB[l=BRANCHES, t=PERIODS],
		sum{load_shift_factor[n,l] * Gen[i,t], n=BUSES, i=GENERATORS; gen_bus_id[i] == n}
		>= sum{load_shift_factor[n,l] * demand_scen[n,t,s], n=BUSES}
		- sum{load_shift_factor[n,l] * wind_scen[wn,t], n=BUSES, wn=WINDS; wind_bus_id[wn] == n}
		- flow_max[l])
	@addConstraint(sb, FLOW_BRANCH_LSF_UB[l=BRANCHES, t=PERIODS],
		sum{load_shift_factor[n,l] * Gen[i,t], n=BUSES, i=GENERATORS; gen_bus_id[i] == n}
		<= sum{load_shift_factor[n,l] * demand_scen[n,t,s], n=BUSES}
		- sum{load_shift_factor[n,l] * wind_scen[wn,t,s], n=BUSES, wn=WINDS; wind_bus_id[wn] == n}
		+ flow_max[l])
end

# Load data to DSP
loadProblem(dsp, m)

end # End of let
