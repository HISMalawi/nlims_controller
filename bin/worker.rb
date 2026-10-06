#!/usr/bin/env ruby
# frozen_string_literal: true

# Entry point for NLIMS background workers
# This script starts all background workers in parallel using fork
# Start all workers

NlimsWorker.start
