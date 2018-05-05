/*
 * DwBranchNonant.h
 *
 *  Created on: May 2, 2018
 *      Author: Kibaek Kim
 * 
 *  This implements the branching on the nonanticipativity constraints, originally proposed in Caroe and Schultz (1999).
 */

#ifndef SRC_SOLVER_DANTZIGWOLFE_DWBRANCHNONANT_H_
#define SRC_SOLVER_DANTZIGWOLFE_DWBRANCHNONANT_H_

#include <DantzigWolfe/DwBranch.h>

class DwBranchNonant : public DwBranch {
public:
	/** default constructor */
	DwBranchNonant() : DwBranch() {}

	/** default constructor with solver */
	DwBranchNonant(DwModel* model) : DwBranch(model) {}

	/** default destructor */
	virtual ~DwBranchNonant() {
	}

    virtual bool chooseBranchingObjects(
    			std::vector<DspBranchObj*>& branchingObjs /**< [out] branching objects */);

protected:

	/** epsilon value for branching on continuous variables */
	double epsilon_ = 1.0e-6;
};

#endif /* SRC_SOLVER_DANTZIGWOLFE_DWBRANCHNONANT_H_ */