from COP_functions import *
import numpy as np
import matplotlib.pyplot as plt
import pickle

# Process Data in `data/baseline/` and `data/intervention/`
processed_data = main()

# Save Processed data as a picle file
pickle.dump(processed_data, open('data/processed_force_plate_data.pkl', 'wb'))