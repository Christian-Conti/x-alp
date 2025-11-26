import sys

sys.path.append('hw/vendor/eslepfl_xheep/util/x_heep_gen')

from x_heep_gen import XHeep

class XAlp(XHeep):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Additional initialization for XAlp can be added here