/*
 * DeDriver.h
 *
 *  Created on: Feb 17, 2016
 *      Author: kibaekkim
 */

#ifndef SRC_SOLVER_DETERMINISTIC_DEDRIVER_H_
#define SRC_SOLVER_DETERMINISTIC_DEDRIVER_H_

/** Coin */
#include "OsiSolverInterface.hpp"
/** Dsp */
#include "Solver/DspDriver.h"

/**
 * This class defines a driver for solving a deterministic equivalent problem.
 */
class DeDriver: public DspDriver {
public:

	/** constructor */
	DeDriver(DspParams * par, DecModel * model);

	/** destructor */
	virtual ~DeDriver();

	/** initilize */
	virtual DSP_RTN_CODE init();

	/** run */
	virtual DSP_RTN_CODE run();

	/** finalize */
	virtual DSP_RTN_CODE finalize();

	/** write extensive form in MPS */
	virtual void writeExtMps(const char * name);

private:

	OsiSolverInterface * si_; /**< my solver interface */
};

#endif /* SRC_SOLVER_DETERMINISTIC_DEDRIVER_H_ */
