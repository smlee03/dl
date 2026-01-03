"""
adaptive_mcs.py
Adaptive MCS adjustment algorithms for V2V groupcast
All parameters are scientifically justified in ADAPTIVE_MCS_DESIGN.md
"""

import numpy as np
from scipy.special import erfc
from typing import Tuple, Dict, List


class AdaptiveMCS:
    """Adaptive MCS adjustment algorithms for V2V groupcast"""

    # BLER thresholds (3GPP TS 22.186)
    BLER_HIGH_THRESHOLD = 0.1   # 10% - Target BLER for V2V
    BLER_LOW_THRESHOLD = 0.01   # 1% - Excellent channel with safety margin

    # MCS adjustment steps (IEEE 802.11p rate adaptation)
    MCS_STEP_DOWN = 2           # Aggressive reduction for degrading channel
    MCS_STEP_UP = 1             # Conservative increase to avoid oscillation

    # MCS range (3GPP TS 36.213)
    MCS_MIN = 0                 # QPSK 1/5 - Most robust
    MCS_MAX = 20                # 64-QAM 3/4 - Maximum for high SINR

    # Window sizes
    BLER_WINDOW_SIZE = 100      # 100 packets = 10s at 10 Hz (ETSI EN 302 637-2)
    SINR_WINDOW_SIZE = 50       # 50ms at 1ms sampling = multiple fading periods

    # Hybrid algorithm penalty
    PENALTY = 3                 # MCS reduction when SINR prediction fails

    # SINR-to-MCS mapping (based on 3GPP TR 36.942)
    SINR_THRESHOLDS = np.array([
        -5, 0, 5, 10, 15, 20, np.inf
    ])
    MCS_VALUES = np.array([0, 2, 5, 9, 14, 17, 20])

    def __init__(self, algorithm_type: str, initial_mcs: int = 9):
        """
        Initialize adaptive MCS controller

        Args:
            algorithm_type: 'fixed', 'bler', 'sinr', 'hybrid'
            initial_mcs: Initial MCS value (default: 9 - 16-QAM 1/2)
        """
        self.algorithm_type = algorithm_type
        self.current_mcs = initial_mcs
        self.bler_window = []
        self.sinr_window = []
        self.mcs_history = [initial_mcs]
        self.time_history = [0.0]

    def update(self, time: float, sinr: float, ack_received: bool) -> int:
        """
        Update MCS based on algorithm type

        Args:
            time: Current simulation time (s)
            sinr: Measured SINR (dB)
            ack_received: True if ACK, False if NAK

        Returns:
            Updated MCS value
        """
        if self.algorithm_type == 'fixed':
            mcs = self._update_fixed()
        elif self.algorithm_type == 'bler':
            mcs = self._update_bler(time, ack_received)
        elif self.algorithm_type == 'sinr':
            mcs = self._update_sinr(time, sinr)
        elif self.algorithm_type == 'hybrid':
            mcs = self._update_hybrid(time, sinr, ack_received)
        else:
            raise ValueError(f"Unknown algorithm type: {self.algorithm_type}")

        self.current_mcs = mcs
        return mcs

    def _update_fixed(self) -> int:
        """Fixed MCS - baseline"""
        return self.current_mcs

    def _update_bler(self, time: float, ack_received: bool) -> int:
        """BLER-based adaptive MCS"""
        # Update BLER window (1 for error, 0 for success)
        self.bler_window.append(0 if ack_received else 1)
        if len(self.bler_window) > self.BLER_WINDOW_SIZE:
            self.bler_window.pop(0)

        # Calculate current BLER
        if len(self.bler_window) >= 10:  # Minimum samples for stability
            current_bler = np.mean(self.bler_window)

            # Adjust MCS based on BLER
            if current_bler > self.BLER_HIGH_THRESHOLD:
                # High error rate - decrease MCS
                new_mcs = max(self.current_mcs - self.MCS_STEP_DOWN, self.MCS_MIN)
            elif current_bler < self.BLER_LOW_THRESHOLD:
                # Low error rate - increase MCS
                new_mcs = min(self.current_mcs + self.MCS_STEP_UP, self.MCS_MAX)
            else:
                # Acceptable BLER - maintain MCS
                new_mcs = self.current_mcs

            # Record MCS change
            if new_mcs != self.current_mcs:
                self.mcs_history.append(new_mcs)
                self.time_history.append(time)

            return new_mcs
        else:
            return self.current_mcs

    def _update_sinr(self, time: float, sinr: float) -> int:
        """SINR-based adaptive MCS"""
        # Update SINR window
        self.sinr_window.append(sinr)
        if len(self.sinr_window) > self.SINR_WINDOW_SIZE:
            self.sinr_window.pop(0)

        # Calculate average SINR
        avg_sinr = np.mean(self.sinr_window)

        # Map SINR to MCS
        new_mcs = self._sinr_to_mcs(avg_sinr)

        # Record MCS change
        if new_mcs != self.current_mcs:
            self.mcs_history.append(new_mcs)
            self.time_history.append(time)

        return new_mcs

    def _update_hybrid(self, time: float, sinr: float, ack_received: bool) -> int:
        """Hybrid adaptive MCS - combines SINR prediction with BLER feedback"""
        # Update windows
        self.sinr_window.append(sinr)
        if len(self.sinr_window) > self.SINR_WINDOW_SIZE:
            self.sinr_window.pop(0)

        self.bler_window.append(0 if ack_received else 1)
        if len(self.bler_window) > self.BLER_WINDOW_SIZE:
            self.bler_window.pop(0)

        # Get SINR-predicted MCS
        avg_sinr = np.mean(self.sinr_window)
        mcs_predicted = self._sinr_to_mcs(avg_sinr)

        # Adjust based on BLER feedback
        if len(self.bler_window) >= 10:
            current_bler = np.mean(self.bler_window)

            if current_bler > self.BLER_HIGH_THRESHOLD:
                # SINR prediction failed - apply penalty
                new_mcs = max(mcs_predicted - self.PENALTY, self.MCS_MIN)
            elif current_bler < self.BLER_LOW_THRESHOLD and \
                 self.current_mcs < mcs_predicted:
                # Gradually increase toward predicted MCS
                new_mcs = min(self.current_mcs + 1, mcs_predicted)
            else:
                # Use predicted MCS
                new_mcs = mcs_predicted
        else:
            new_mcs = mcs_predicted

        # Record MCS change
        if new_mcs != self.current_mcs:
            self.mcs_history.append(new_mcs)
            self.time_history.append(time)

        return new_mcs

    def _sinr_to_mcs(self, sinr: float) -> int:
        """Map SINR to MCS based on 3GPP TR 36.942"""
        idx = np.searchsorted(self.SINR_THRESHOLDS, sinr)
        return int(self.MCS_VALUES[min(idx, len(self.MCS_VALUES) - 1)])

    def get_statistics(self) -> Dict:
        """Get performance statistics"""
        stats = {
            'algorithm': self.algorithm_type,
            'final_mcs': self.current_mcs,
            'mcs_history': self.mcs_history,
            'time_history': self.time_history,
            'num_changes': len(self.mcs_history) - 1
        }

        if stats['num_changes'] > 0:
            total_time = self.time_history[-1] - self.time_history[0]
            stats['change_frequency'] = stats['num_changes'] / total_time
        else:
            stats['change_frequency'] = 0.0

        return stats


class NLOSModel:
    """NLOS channel model with vehicle blocking"""

    # Path loss per blocking vehicle (WINNER+ B1 V2V model)
    ALPHA = 3.0              # dB per vehicle (empirical measurements: 2-5 dB)

    # Base NLOS penalty (ITU-R M.2135 urban micro-cell NLOS)
    BETA = 5.0               # dB (first diffraction loss)

    # V2V frequency
    CARRIER_FREQ_GHZ = 5.9   # ITS-G5 band (ETSI EN 302 571)

    # Transmit power
    P_TX_DBM = 23.0          # Max power for V2V (ETSI EN 302 571)

    # Noise floor (10 MHz bandwidth, 9 dB noise figure)
    NOISE_FLOOR_DBM = -95.0  # N0 = -174 + 10*log10(10e6) + 9

    # Shadowing standard deviation (3GPP TR 36.885)
    SIGMA_SHADOW_LOS = 3.0   # dB (LOS)
    SIGMA_SHADOW_NLOS = 4.0  # dB (NLOS)

    def __init__(self, n_blocking: int = 0):
        """
        Initialize NLOS channel model

        Args:
            n_blocking: Number of blocking vehicles (0-5)
                       0 = LOS, >=1 = NLOS
        """
        if n_blocking < 0 or n_blocking > 5:
            raise ValueError("n_blocking must be in range [0, 5]")

        self.n_blocking = n_blocking

    def compute_path_loss(self, distance_m: float) -> float:
        """
        Compute path loss based on 3GPP TR 36.885 V2V model

        Args:
            distance_m: Distance in meters

        Returns:
            Path loss in dB
        """
        # LOS path loss (3GPP TR 36.885)
        pl_los = 38.77 + 16.7 * np.log10(distance_m) + \
                 18.2 * np.log10(self.CARRIER_FREQ_GHZ)

        # Additional NLOS loss
        if self.n_blocking > 0:
            pl_nlos_additional = self.ALPHA * self.n_blocking + self.BETA
            pl = pl_los + pl_nlos_additional
        else:
            pl = pl_los

        return pl

    def compute_sinr(self, distance_m: float,
                    interference_dbm: float = -120.0) -> float:
        """
        Compute SINR

        Args:
            distance_m: Distance in meters
            interference_dbm: Interference power in dBm

        Returns:
            SINR in dB
        """
        # Compute path loss
        pl = self.compute_path_loss(distance_m)

        # Add shadowing (log-normal)
        sigma_shadow = self.SIGMA_SHADOW_NLOS if self.n_blocking > 0 \
                      else self.SIGMA_SHADOW_LOS
        shadowing = sigma_shadow * np.random.randn()

        # Received power
        p_rx = self.P_TX_DBM - pl - shadowing

        # Total noise + interference
        noise_plus_interference = 10 * np.log10(
            10**(self.NOISE_FLOOR_DBM/10) + 10**(interference_dbm/10)
        )

        # SINR
        sinr = p_rx - noise_plus_interference

        return sinr

    def compute_bler(self, sinr: float, mcs: int) -> float:
        """
        Compute BLER based on SINR and MCS
        Uses empirical AWGN BLER curves from 3GPP TR 36.942

        Args:
            sinr: SINR in dB
            mcs: MCS index (0-20)

        Returns:
            Block error rate [0, 1]
        """
        # SINR thresholds for 10% BLER at each MCS (3GPP TR 36.942)
        sinr_threshold = np.array([
            -5, -3, 0, 2, 5, 7, 9, 11, 13, 15,
            17, 19, 21, 23, 25, 27, 29, 31, 33, 35, 37
        ])

        if mcs < 0 or mcs > 20:
            raise ValueError("MCS must be in range [0, 20]")

        # Get threshold for this MCS
        threshold = sinr_threshold[mcs]

        # BLER curve shape (exponential model)
        sigma = 2.0  # Curve steepness parameter
        bler = 0.5 * erfc((sinr - threshold) / sigma)

        # Clamp to [0, 1]
        return np.clip(bler, 0.0, 1.0)

    def simulate_transmission(self, sinr: float, mcs: int) -> bool:
        """
        Simulate packet transmission

        Args:
            sinr: SINR in dB
            mcs: MCS index

        Returns:
            True if ACK (success), False if NAK (error)
        """
        bler = self.compute_bler(sinr, mcs)
        return np.random.rand() > bler


class PlatooningScenario:
    """Vehicle platooning scenario configuration"""

    # Vehicle configuration (ETSI TR 103 299)
    N_VEHICLES = 5              # Typical platoon size

    # Spacing parameters
    INITIAL_SPACING_M = 15.0    # Safe distance at highway speeds
    TARGET_SPACING_M = 5.0      # Target for automated platooning

    # Velocity parameters
    BASE_VELOCITY_MS = 25.0     # 90 km/h
    VELOCITY_DIFFERENTIAL_MS = 0.5  # Rear vehicles faster

    def __init__(self, n_vehicles: int = 5):
        """Initialize platooning scenario"""
        self.n_vehicles = n_vehicles
        self.time = 0.0

        # Initialize positions (leader at origin)
        self.positions = np.zeros(n_vehicles)
        for i in range(1, n_vehicles):
            self.positions[i] = self.positions[i-1] - self.INITIAL_SPACING_M

        # Initialize velocities (rear vehicles faster)
        self.velocities = np.ones(n_vehicles) * self.BASE_VELOCITY_MS
        for i in range(1, n_vehicles):
            self.velocities[i] += i * self.VELOCITY_DIFFERENTIAL_MS

        self._update_spacings()

    def _update_spacings(self):
        """Update inter-vehicle spacings"""
        self.spacings = np.diff(self.positions) * -1  # Positive spacing

    def update(self, dt: float):
        """Update vehicle positions"""
        # Update positions
        self.positions += self.velocities * dt

        # Simple platoon control
        for i in range(1, self.n_vehicles):
            current_spacing = self.positions[i-1] - self.positions[i]
            spacing_error = current_spacing - self.TARGET_SPACING_M

            # Proportional controller
            K_p = 0.3
            velocity_adjustment = K_p * spacing_error

            # Limit adjustment
            velocity_adjustment = np.clip(velocity_adjustment, -2.0, 2.0)

            # Update velocity
            self.velocities[i] = self.BASE_VELOCITY_MS + velocity_adjustment

        self._update_spacings()
        self.time += dt

    def get_distance(self, vehicle_i: int, vehicle_j: int) -> float:
        """Get distance between two vehicles"""
        return abs(self.positions[vehicle_i] - self.positions[vehicle_j])

    def get_n_blocking_vehicles(self, tx_vehicle: int, rx_vehicle: int) -> int:
        """Get number of blocking vehicles between transmitter and receiver"""
        min_idx = min(tx_vehicle, rx_vehicle)
        max_idx = max(tx_vehicle, rx_vehicle)
        n_blocking = max_idx - min_idx - 1
        return min(n_blocking, 5)  # Cap at 5


# Spectral efficiency (bits/symbol) for each MCS (3GPP TS 36.213)
SPECTRAL_EFFICIENCY = np.array([
    0.1523, 0.2344, 0.3770, 0.6016, 0.8770, 1.1758, 1.4766,
    1.9141, 2.4063, 2.7305, 3.3223, 3.9023, 4.5234, 5.1152,
    5.5547, 6.2266, 6.9141, 7.4063, 8.0977, 8.9063, 9.6094
])


def get_bits_per_packet(mcs: int) -> int:
    """Get bits per packet based on MCS"""
    num_rbs = 10  # Resource blocks per packet
    symbols_per_rb = 84  # 12 subcarriers * 7 symbols
    total_symbols = num_rbs * symbols_per_rb
    return int(SPECTRAL_EFFICIENCY[mcs] * total_symbols)
