/*
 * DwModel.cpp
 *
 *  Created on: Feb 13, 2017
 *      Author: kibaekkim
 */

#include <DantzigWolfe/DwModel.h>
#include <DantzigWolfe/DwHeuristic.h>

DwModel::DwModel(): DspModel(), master_(NULL), infeasibility_(0.0) {}

DwModel::DwModel(DecSolver* solver): DspModel(solver), infeasibility_(0.0) {
	master_ = dynamic_cast<DwMaster*>(solver_);
	primsol_.resize(master_->ncols_orig_);
	heuristics_.push_back(new DwRounding("Rounding", *this));
}

DwModel::~DwModel() {
	for (unsigned i = 0; i < heuristics_.size(); ++i)
		delete heuristics_[i];
}

DSP_RTN_CODE DwModel::solve() {
	BGN_TRY_CATCH

	/** set best primal objective value */
	solver_->setBestPrimalObjective(bestprimobj_);

	/** solve master */
	solver_->solve();

	status_ = solver_->getStatus();

	switch (status_) {
	case DSP_STAT_OPTIMAL:
	case DSP_STAT_FEASIBLE:
	case DSP_STAT_LIM_ITERorTIME: {

		primobj_ = master_->getPrimalObjective();
		dualobj_ = -master_->getBestDualObjective();

		if (primobj_ < 1.0e+20) {
			/** parse solution */
			int cpos = 0;
			std::fill(primsol_.begin(), primsol_.begin() + master_->ncols_orig_, 0.0);
			for (auto it = master_->cols_generated_.begin(); it != master_->cols_generated_.end(); it++) {
				if ((*it)->active_) {
					for (int i = 0; i < (*it)->x_.getNumElements(); ++i) {
						if ((*it)->x_.getIndices()[i] < master_->ncols_orig_)
							primsol_[(*it)->x_.getIndices()[i]] += (*it)->x_.getElements()[i] * master_->getPrimalSolution()[cpos];
					}
					cpos++;
				}
			}
			//DspMessage::printArray(cpos, master_->getPrimalSolution());

			/** calculate infeasibility */
			infeasibility_ = 0.0;
			for (int j = 0; j < master_->ncols_orig_; ++j)
				if (master_->ctype_orig_[j] != 'C') {
					infeasibility_ += fabs(primsol_[j] - floor(primsol_[j] + 0.5));
				}
			printf("Infeasibility: %+e\n", infeasibility_);

			for (int j = 0; j < master_->ncols_orig_; ++j) {
				double viol = std::max(master_->clbd_node_[j] - primsol_[j], primsol_[j] - master_->cubd_node_[j]);
				if (viol > 1.0e-6) {
					printf("Violated variable at %d by %e (%+e <= %+e <= %+e)\n", j, viol,
							master_->clbd_node_[j], primsol_[j], master_->cubd_node_[j]);
				}
			}

			/** run heuristics */
			if (par_->getBoolParam("DW/HEURISTICS") && infeasibility_ > 1.0e-6) {
				/** FIXME */
				bestprimobj_ = COIN_DBL_MAX;
				for (auto it = heuristics_.begin(); it != heuristics_.end(); it++) {
					printf("Running [%s] heuristic:\n", (*it)->name());
					int found = (*it)->solution(bestprimobj_, bestprimsol_);
					//printf("found %d bestprimobj %+e\n", found, bestprimobj_);
				}
			}
		}

		break;
	}
	default:
		break;
	}

	END_TRY_CATCH_RTN(;,DSP_RTN_ERR)

	return DSP_RTN_OK;
}

bool DwModel::chooseBranchingObjects(
		DspBranch*& branchingUp, /**< [out] branching-up object */
		DspBranch*& branchingDn  /**< [out] branching-down object */) {
	int findPhase = 0;
	bool branched = false;
	double dist, maxdist = 1.0e-6;
	int branchingIndex = -1;
	double branchingValue;

	BGN_TRY_CATCH

	/** cleanup */
	FREE_PTR(branchingUp)
	FREE_PTR(branchingDn)

	findPhase = 0;
	while (findPhase < 2 && branchingIndex < 0) {
		/** most fractional value */
		for (int j = 0; j < master_->ncols_orig_; ++j) {
			if (master_->ctype_orig_[j] == 'C') continue;
			dist = fabs(primsol_[j] - floor(primsol_[j] + 0.5));
			if (dist > maxdist) {
				maxdist = dist;
				branchingIndex = j;
				branchingValue = primsol_[j];
			}
		}
		findPhase++;
	}

	if (branchingIndex > -1) {
		DSPdebugMessage("Creating branch objects on column %d (value %e).\n", branchingIndex, branchingValue);
		branched = true;

		/** creating branching objects */
		branchingUp = new DspBranch();
		branchingDn = new DspBranch();
		for (int j = 0; j < master_->ncols_orig_; ++j) {
			if (master_->ctype_orig_[j] == 'C') continue;
			if (branchingIndex == j) {
				branchingUp->push_back(j, ceil(branchingValue), master_->cubd_node_[j]);
				branchingDn->push_back(j, master_->clbd_node_[j], floor(branchingValue));
			} else if (master_->clbd_node_[j] > master_->clbd_orig_[j] || master_->cubd_node_[j] < master_->cubd_orig_[j]) {
				/** store any bound changes made in parent nodes */
				branchingUp->push_back(j, master_->clbd_node_[j], master_->cubd_node_[j]);
				branchingDn->push_back(j, master_->clbd_node_[j], master_->cubd_node_[j]);
			}
		}
		branchingUp->bestBound_ = master_->getBestDualObjective();
		branchingDn->bestBound_ = master_->getBestDualObjective();
		branchingUp->dualsol_.assign(master_->getBestDualSolution(), master_->getBestDualSolution() + master_->nrows_);
		branchingDn->dualsol_.assign(master_->getBestDualSolution(), master_->getBestDualSolution() + master_->nrows_);
	} else {
		DSPdebugMessage("No branch object is found.\n");
	}

	END_TRY_CATCH_RTN(;,false)

	return branched;
}

