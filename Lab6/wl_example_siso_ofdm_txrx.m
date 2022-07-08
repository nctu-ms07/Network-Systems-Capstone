%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% wl_example_siso_ofdm_txrx.m
% A detailed write-up of this example is available on the wiki:
% http://warpproject.org/trac/wiki/WARPLab/Examples/OFDM
%
% Copyright (c) 2015 Mango Communications - All Rights Reserved
% Distributed under the WARP License (http://warpproject.org/license)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear

%Homework:
file = matfile('input.mat');
H = file.H;
n_vec = file.n_vec;

% Params:
USE_WARPLAB_TXRX        = 0;           % Enable WARPLab-in-the-loop (otherwise sim-only)
WRITE_PNG_FILES         = 0;           % Enable writing plots to PNG
CHANNEL                 = 11;          % Channel to tune Tx and Rx radios

% Waveform params
N_OFDM_SYMS             = 500;         % Number of OFDM symbols
MOD_ORDER               = 16;           % Modulation order (2/4/16/64 = BSPK/QPSK/16-QAM/64-QAM)
TX_SCALE                = 1.0;          % Scale for Tx waveform ([0:1])

% OFDM params
SC_IND_PILOTS           = [8 22 44 58];                           % Pilot subcarrier indices
SC_IND_DATA             = [2:7 9:21 23:27 39:43 45:57 59:64];     % Data subcarrier indices
N_SC                    = 64;                                     % Number of subcarriers
CP_LEN                  = 16;                                     % Cyclic prefix length
N_DATA_SYMS             = N_OFDM_SYMS * length(SC_IND_DATA);      % Number of data symbols (one per data-bearing subcarrier per OFDM symbol)
INTERP_RATE             = 2;                                      % Interpolation rate (must be 2)

% Rx processing params
FFT_OFFSET                    = 4;           % Number of CP samples to use in FFT (on average)
LTS_CORR_THRESH               = 0.8;         % Normalized threshold for LTS correlation
DO_APPLY_CFO_CORRECTION       = 1;           % Enable CFO estimation/correction
DO_APPLY_PHASE_ERR_CORRECTION = 1;           % Enable Residual CFO estimation/correction
DO_APPLY_SFO_CORRECTION       = 1;           % Enable SFO estimation/correction

DECIMATE_RATE                 = INTERP_RATE;

% WARPLab experiment params
USE_AGC                 = true;        % Use the AGC if running on WARP hardware
MAX_TX_LEN              = 2^20;        % Maximum number of samples to use for this experiment
TRIGGER_OFFSET_TOL_NS   = 3000;        % Trigger time offset toleration between Tx and Rx that can be accomodated



if(USE_WARPLAB_TXRX)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Set up the WARPLab experiment
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    NUMNODES = 2;

    % Create a vector of node objects
    nodes   = wl_initNodes(NUMNODES);
    node_tx = nodes(1);
    node_rx = nodes(2);

    % Create a UDP broadcast trigger and tell each node to be ready for it
    eth_trig = wl_trigger_eth_udp_broadcast;
    wl_triggerManagerCmd(nodes, 'add_ethernet_trigger', [eth_trig]);

    % Read Trigger IDs into workspace
    trig_in_ids  = wl_getTriggerInputIDs(nodes(1));
    trig_out_ids = wl_getTriggerOutputIDs(nodes(1));

    % For both nodes, we will allow Ethernet to trigger the buffer baseband and the AGC
    wl_triggerManagerCmd(nodes, 'output_config_input_selection', [trig_out_ids.BASEBAND, trig_out_ids.AGC], [trig_in_ids.ETH_A]);

    % Set the trigger output delays.
    nodes.wl_triggerManagerCmd('output_config_delay', [trig_out_ids.BASEBAND], 0);
    nodes.wl_triggerManagerCmd('output_config_delay', [trig_out_ids.AGC], TRIGGER_OFFSET_TOL_NS);

    % Get IDs for the interfaces on the boards. 
    ifc_ids_TX = wl_getInterfaceIDs(node_tx);
    ifc_ids_RX = wl_getInterfaceIDs(node_rx);

    % Set up the TX / RX nodes and RF interfaces
    TX_RF     = ifc_ids_TX.RF_A;
    TX_RF_VEC = ifc_ids_TX.RF_A;
    TX_RF_ALL = ifc_ids_TX.RF_ALL;
    
    RX_RF     = ifc_ids_RX.RF_A;
    RX_RF_VEC = ifc_ids_RX.RF_A;
    RX_RF_ALL = ifc_ids_RX.RF_ALL;

    % Set up the interface for the experiment
    wl_interfaceCmd(node_tx, TX_RF_ALL, 'channel', 2.4, CHANNEL);
    wl_interfaceCmd(node_rx, RX_RF_ALL, 'channel', 2.4, CHANNEL);

    wl_interfaceCmd(node_tx, TX_RF_ALL, 'tx_gains', 3, 30);

    if(USE_AGC)
        wl_interfaceCmd(node_rx, RX_RF_ALL, 'rx_gain_mode', 'automatic');
        wl_basebandCmd(nodes, 'agc_target', -13);
    else
        wl_interfaceCmd(node_rx, RX_RF_ALL, 'rx_gain_mode', 'manual');
        RxGainRF = 2;                  % Rx RF Gain in [1:3]
        RxGainBB = 12;                 % Rx Baseband Gain in [0:31]
        wl_interfaceCmd(node_rx, RX_RF_ALL, 'rx_gains', RxGainRF, RxGainBB);
    end

    % Get parameters from the node
    SAMP_FREQ    = wl_basebandCmd(nodes(1), 'tx_buff_clk_freq');
    Ts           = 1/SAMP_FREQ;

    % We will read the transmitter's maximum I/Q buffer length
    % and assign that value to a temporary variable.
    %
    % NOTE:  We assume that the buffers sizes are the same for all interfaces

    maximum_buffer_len = min(MAX_TX_LEN, wl_basebandCmd(node_tx, TX_RF_VEC, 'tx_buff_max_num_samples'));
    example_mode_string = 'hw';
else
    % Use sane defaults for hardware-dependent params in sim-only version
    maximum_buffer_len = min(MAX_TX_LEN, 2^20);
    SAMP_FREQ           = 40e6;
    example_mode_string = 'sim';
end

%% Define a half-band 2x interpolation filter response
interp_filt2 = zeros(1,43);
interp_filt2([1 3 5 7 9 11 13 15 17 19 21]) = [12 -32 72 -140 252 -422 682 -1086 1778 -3284 10364];
interp_filt2([23 25 27 29 31 33 35 37 39 41 43]) = interp_filt2(fliplr([1 3 5 7 9 11 13 15 17 19 21]));
interp_filt2(22) = 16384;
interp_filt2 = interp_filt2./max(abs(interp_filt2));

% Define the preamble
% Note: The STS symbols in the preamble meet the requirements needed by the
% AGC core at the receiver. Details on the operation of the AGC are
% available on the wiki: http://warpproject.org/trac/wiki/WARPLab/AGC
sts_f = zeros(1,64);
sts_f(1:27) = [0 0 0 0 -1-1i 0 0 0 -1-1i 0 0 0 1+1i 0 0 0 1+1i 0 0 0 1+1i 0 0 0 1+1i 0 0];
sts_f(39:64) = [0 0 1+1i 0 0 0 -1-1i 0 0 0 1+1i 0 0 0 -1-1i 0 0 0 -1-1i 0 0 0 1+1i 0 0 0];
sts_t = ifft(sqrt(13/6).*sts_f, 64);
sts_t = sts_t(1:16);

% LTS for CFO and channel estimation
lts_f = [0 1 -1 -1 1 1 -1 1 -1 1 -1 -1 -1 -1 -1 1 1 -1 -1 1 -1 1 -1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 1 1 -1 -1 1 1 -1 1 -1 1 1 1 1 1 1 -1 -1 1 1 -1 1 -1 1 1 1 1];
lts_t = ifft(lts_f .* H, 64);

% Use 30 copies of the 16-sample STS for extra AGC settling margin
preamble = [repmat(sts_t, 1, 30)  lts_t(33:64) lts_t lts_t];

% Sanity check variables that affect the number of Tx samples
num_samps_needed = ceil((TRIGGER_OFFSET_TOL_NS*1e-9) / (1/SAMP_FREQ)) + ...
                    INTERP_RATE*((N_OFDM_SYMS * (N_SC + CP_LEN)) + length(preamble) +  ceil(length(interp_filt2)/2));

                                
if(num_samps_needed > maximum_buffer_len)
    fprintf('Too many OFDM symbols for TX_NUM_SAMPS!\n');
    fprintf('Raise MAX_TX_LEN to %d, or \n', num_samps_needed);
    fprintf('Reduce N_OFDM_SYMS to %d\n', floor(((maximum_buffer_len - ceil((TRIGGER_OFFSET_TOL_NS*1e-9) / (1/SAMP_FREQ)))/INTERP_RATE - (length(preamble) +  ceil(length(interp_filt2)/2)))/(N_SC + CP_LEN)));
    return;
end

%% Generate a payload of random integers
tx_data = randi(MOD_ORDER, 1, N_DATA_SYMS) - 1;

% Functions for data -> complex symbol mapping (like qammod, avoids comm toolbox requirement)
% These anonymous functions implement the modulation mapping from IEEE 802.11-2012 Section 18.3.5.8
modvec_bpsk   =  (1/sqrt(2))  .* [-1 1];
modvec_16qam  =  (1/sqrt(10)) .* [-3 -1 +3 +1];
modvec_64qam  =  (1/sqrt(43)) .* [-7 -5 -1 -3 +7 +5 +1 +3];

mod_fcn_bpsk  = @(x) complex(modvec_bpsk(1+x),0);
mod_fcn_qpsk  = @(x) complex(modvec_bpsk(1+bitshift(x, -1)), modvec_bpsk(1+mod(x, 2)));
mod_fcn_16qam = @(x) complex(modvec_16qam(1+bitshift(x, -2)), modvec_16qam(1+mod(x,4)));
mod_fcn_64qam = @(x) complex(modvec_64qam(1+bitshift(x, -3)), modvec_64qam(1+mod(x,8)));

% Map the data values on to complex symbols
switch MOD_ORDER
    case 2         % BPSK
        tx_syms = arrayfun(mod_fcn_bpsk, tx_data);
    case 4         % QPSK
        tx_syms = arrayfun(mod_fcn_qpsk, tx_data);
    case 16        % 16-QAM
        tx_syms = arrayfun(mod_fcn_16qam, tx_data);
    case 64        % 64-QAM
        tx_syms = arrayfun(mod_fcn_64qam, tx_data);
    otherwise
        fprintf('Invalid MOD_ORDER (%d)!  Must be in [2, 4, 16, 64]\n', MOD_ORDER);
        return;
end

% Reshape the symbol vector to a matrix with one column per OFDM symbol
tx_syms_mat = reshape(tx_syms, length(SC_IND_DATA), N_OFDM_SYMS);

% Define the pilot tone values as BPSK symbols
pilots = [1 1 -1 1].';

% Repeat the pilots across all OFDM symbols
pilots_mat = repmat(pilots, 1, N_OFDM_SYMS);

%% IFFT

% Construct the IFFT input matrix
ifft_in_mat = zeros(N_SC, N_OFDM_SYMS);

% Insert the data and pilot values; other subcarriers will remain at 0
ifft_in_mat(SC_IND_DATA, :)   = tx_syms_mat;
ifft_in_mat(SC_IND_PILOTS, :) = pilots_mat;
ifft_in_mat = ifft_in_mat .* repmat(H.', 1, N_OFDM_SYMS);

%Perform the IFFT
tx_payload_mat = ifft(ifft_in_mat, N_SC, 1);

% Insert the cyclic prefix
if(CP_LEN > 0)
    tx_cp = tx_payload_mat((end-CP_LEN+1 : end), :);
    tx_payload_mat = [tx_cp; tx_payload_mat];
end

% Reshape to a vector
tx_payload_vec = reshape(tx_payload_mat, 1, numel(tx_payload_mat));

% Construct the full time-domain OFDM waveform
tx_vec = [preamble tx_payload_vec];

% Pad with zeros for transmission to deal with delay through the
% interpolation filter
tx_vec_padded = [tx_vec, zeros(1, ceil(length(interp_filt2)/2))];

%% Interpolate
% Zero pad then filter (same as interp or upfirdn without signal processing toolbox)
if( INTERP_RATE ~= 2)
   fprintf('Error: INTERP_RATE must equal 2\n'); 
   return;
end

tx_vec_2x = zeros(1, 2*numel(tx_vec_padded));
tx_vec_2x(1:2:end) = tx_vec_padded;
tx_vec_air = filter(interp_filt2, 1, tx_vec_2x);


% Scale the Tx vector to +/- 1
%tx_vec_air = TX_SCALE .* tx_vec_air ./ max(abs(tx_vec_air));

TX_NUM_SAMPS = length(tx_vec_air);

if(USE_WARPLAB_TXRX)
    wl_basebandCmd(nodes, 'tx_delay', 0);
    wl_basebandCmd(nodes, 'tx_length', TX_NUM_SAMPS);                                                        % Number of samples to send
    wl_basebandCmd(nodes, 'rx_length', TX_NUM_SAMPS + ceil((TRIGGER_OFFSET_TOL_NS*1e-9) / (1/SAMP_FREQ)));   % Number of samples to receive
end


%% WARPLab Tx/Rx
if(USE_WARPLAB_TXRX)
    % Write the Tx waveform to the Tx node
    wl_basebandCmd(node_tx, TX_RF_VEC, 'write_IQ', tx_vec_air(:));

    % Enable the Tx and Rx radios
    wl_interfaceCmd(node_tx, TX_RF, 'tx_en');
    wl_interfaceCmd(node_rx, RX_RF, 'rx_en');

    % Enable the Tx and Rx buffers
    wl_basebandCmd(node_tx, TX_RF, 'tx_buff_en');
    wl_basebandCmd(node_rx, RX_RF, 'rx_buff_en');

    % Trigger the Tx/Rx cycle at both nodes
    eth_trig.send();

    % Retrieve the received waveform from the Rx node
    rx_vec_air = wl_basebandCmd(node_rx, RX_RF_VEC, 'read_IQ', 0, TX_NUM_SAMPS + (ceil((TRIGGER_OFFSET_TOL_NS*1e-9) / (1/SAMP_FREQ))));

    rx_vec_air = rx_vec_air(:).';

    % Disable the Tx/Rx radios and buffers
    wl_basebandCmd(node_tx, TX_RF_ALL, 'tx_rx_buff_dis');
    wl_basebandCmd(node_rx, RX_RF_ALL, 'tx_rx_buff_dis');
    
    wl_interfaceCmd(node_tx, TX_RF_ALL, 'tx_rx_dis');
    wl_interfaceCmd(node_rx, RX_RF_ALL, 'tx_rx_dis');
else
    % Sim-only mode: Apply wireless degradations here for sim (noise, fading, etc)

    % Perfect (ie. Rx=Tx):
    % rx_vec_air = tx_vec_air;

    % AWGN:
    rx_vec_air = [tx_vec_air, zeros(1,ceil((TRIGGER_OFFSET_TOL_NS*1e-9) / (1/SAMP_FREQ)))];
    %rx_vec_air = rx_vec_air + 0*complex(randn(1,length(rx_vec_air)), randn(1,length(rx_vec_air)));
	
	rx_vec_air = rx_vec_air + n_vec;

    % CFO:
    % rx_vec_air = tx_vec_air .* exp(-1i*2*pi*1e-4*[0:length(tx_vec_air)-1]);
end

%% Decimate
if( INTERP_RATE ~= 2)
   fprintf('Error: INTERP_RATE must equal 2\n'); 
   return;
end

raw_rx_dec = filter(interp_filt2, 1, rx_vec_air);
raw_rx_dec = raw_rx_dec(1:2:end)/2;


%% Correlate for LTS

% Complex cross correlation of Rx waveform with time-domain LTS
lts_corr = abs(conv(conj(fliplr(lts_t)), sign(raw_rx_dec)));

% Skip early and late samples - avoids occasional false positives from pre-AGC samples
lts_corr = lts_corr(32:end-32);

% Find all correlation peaks
lts_peaks = find(lts_corr(1:800) > LTS_CORR_THRESH*max(lts_corr));

% Select best candidate correlation peak as LTS-payload boundary
[LTS1, LTS2] = meshgrid(lts_peaks,lts_peaks);
[lts_second_peak_index,y] = find(LTS2-LTS1 == length(lts_t));

% Stop if no valid correlation peak was found
if(isempty(lts_second_peak_index))
    fprintf('No LTS Correlation Peaks Found!\n');
    return;
end

% Set the sample indices of the payload symbols and preamble
% The "+32" corresponds to the 32-sample cyclic prefix on the preamble LTS
% The "-160" corresponds to the length of the preamble LTS (2.5 copies of 64-sample LTS)
payload_ind = lts_peaks(max(lts_second_peak_index)) + 32;
lts_ind = payload_ind-160;

if(DO_APPLY_CFO_CORRECTION)
    %Extract LTS (not yet CFO corrected)
    rx_lts = raw_rx_dec(lts_ind : lts_ind+159);
    rx_lts1 = rx_lts(-64+-FFT_OFFSET + [97:160]);
    rx_lts2 = rx_lts(-FFT_OFFSET + [97:160]);

    %Calculate coarse CFO est
    rx_cfo_est_lts = mean(unwrap(angle(rx_lts2 .* conj(rx_lts1))));
    rx_cfo_est_lts = rx_cfo_est_lts/(2*pi*64);
else
    rx_cfo_est_lts = 0;
end

% Apply CFO correction to raw Rx waveform
rx_cfo_corr_t = exp(-1i*2*pi*rx_cfo_est_lts*[0:length(raw_rx_dec)-1]);
rx_dec_cfo_corr = raw_rx_dec .* rx_cfo_corr_t;

% Re-extract LTS for channel estimate
rx_lts = rx_dec_cfo_corr(lts_ind : lts_ind+159);
rx_lts1 = rx_lts(-64+-FFT_OFFSET + [97:160]);
rx_lts2 = rx_lts(-FFT_OFFSET + [97:160]);

rx_lts1_f = fft(rx_lts1);
rx_lts2_f = fft(rx_lts2);

% Calculate channel estimate from average of 2 training symbols
rx_H_est = lts_f .* (rx_lts1_f + rx_lts2_f)/2;

%% Rx payload processing

% Extract the payload samples (integral number of OFDM symbols following preamble)
payload_vec = rx_dec_cfo_corr(payload_ind : payload_ind+N_OFDM_SYMS*(N_SC+CP_LEN)-1);
payload_mat = reshape(payload_vec, (N_SC+CP_LEN), N_OFDM_SYMS);

% Remove the cyclic prefix, keeping FFT_OFFSET samples of CP (on average)
payload_mat_noCP = payload_mat(CP_LEN-FFT_OFFSET+[1:N_SC], :);

% Take the FFT
syms_f_mat = fft(payload_mat_noCP, N_SC, 1);

% Equalize (zero-forcing, just divide by complex chan estimates)
syms_eq_mat = syms_f_mat ./ repmat(rx_H_est.', 1, N_OFDM_SYMS);

if DO_APPLY_SFO_CORRECTION
    % SFO manifests as a frequency-dependent phase whose slope increases
    % over time as the Tx and Rx sample streams drift apart from one
    % another. To correct for this effect, we calculate this phase slope at
    % each OFDM symbol using the pilot tones and use this slope to
    % interpolate a phase correction for each data-bearing subcarrier.

	% Extract the pilot tones and "equalize" them by their nominal Tx values
    pilots_f_mat = syms_eq_mat(SC_IND_PILOTS, :);
    pilots_f_mat_comp = pilots_f_mat.*pilots_mat;

	% Calculate the phases of every Rx pilot tone
    pilot_phases = unwrap(angle(fftshift(pilots_f_mat_comp,1)), [], 1);

	% Calculate slope of pilot tone phases vs frequency in each OFDM symbol
    pilot_spacing_mat = repmat(mod(diff(fftshift(SC_IND_PILOTS)),64).', 1, N_OFDM_SYMS);                        
	pilot_slope_mat = mean(diff(pilot_phases) ./ pilot_spacing_mat);

	% Calculate the SFO correction phases for each OFDM symbol
    pilot_phase_sfo_corr = fftshift((-32:31).' * pilot_slope_mat, 1);
    pilot_phase_corr = exp(-1i*(pilot_phase_sfo_corr));

    % Apply the pilot phase correction per symbol
    syms_eq_mat = syms_eq_mat .* pilot_phase_corr;
else
	% Define an empty SFO correction matrix (used by plotting code below)
    pilot_phase_sfo_corr = zeros(N_SC, N_OFDM_SYMS);
end


if DO_APPLY_PHASE_ERR_CORRECTION
    % Extract the pilots and calculate per-symbol phase error
    pilots_f_mat = syms_eq_mat(SC_IND_PILOTS, :);
    pilots_f_mat_comp = pilots_f_mat.*pilots_mat;
    pilot_phase_err = angle(mean(pilots_f_mat_comp));
else
	% Define an empty phase correction vector (used by plotting code below)
    pilot_phase_err = zeros(1, N_OFDM_SYMS);
end
pilot_phase_err_corr = repmat(pilot_phase_err, N_SC, 1);
pilot_phase_corr = exp(-1i*(pilot_phase_err_corr));

% Apply the pilot phase correction per symbol
syms_eq_pc_mat = syms_eq_mat .* pilot_phase_corr;
payload_syms_mat = syms_eq_pc_mat(SC_IND_DATA, :);

%% Demodulate
rx_syms = reshape(payload_syms_mat, 1, N_DATA_SYMS);

demod_fcn_bpsk = @(x) double(real(x)>0);
demod_fcn_qpsk = @(x) double(2*(real(x)>0) + 1*(imag(x)>0));
demod_fcn_16qam = @(x) (8*(real(x)>0)) + (4*(abs(real(x))<0.6325)) + (2*(imag(x)>0)) + (1*(abs(imag(x))<0.6325));
demod_fcn_64qam = @(x) (32*(real(x)>0)) + (16*(abs(real(x))<0.6172)) + (8*((abs(real(x))<(0.9258))&&((abs(real(x))>(0.3086))))) + (4*(imag(x)>0)) + (2*(abs(imag(x))<0.6172)) + (1*((abs(imag(x))<(0.9258))&&((abs(imag(x))>(0.3086)))));

switch(MOD_ORDER)
    case 2         % BPSK
        rx_data = arrayfun(demod_fcn_bpsk, rx_syms);
    case 4         % QPSK
        rx_data = arrayfun(demod_fcn_qpsk, rx_syms);
    case 16        % 16-QAM
        rx_data = arrayfun(demod_fcn_16qam, rx_syms);
    case 64        % 64-QAM
        rx_data = arrayfun(demod_fcn_64qam, rx_syms);
end

fprintf('\nResults:\n');
fprintf('estimated channels of data subcarriers\n');
disp(rx_H_est(SC_IND_DATA));

%% Plot Results
cf = 0;

%% power of channel responses of the data subcarriers
cf = cf + 1;
figure(cf); clf;

power = abs(rx_H_est).^2;
bar(power(SC_IND_DATA));
xlabel('Data Symbol Index');
ylabel('power of channel');
title('power of channel responses of the data subcarriers');

[A,I] = min(power(SC_IND_DATA));
fprintf('data subcarriers experiences the minimum receiving power: %d\n',I);

%% average SNR(dB) of each subcarriers
cf = cf + 1;
figure(cf); clf;

evm_mat = abs(payload_syms_mat - tx_syms_mat).^2;
aevms = mean(evm_mat,2);
snr = 10*log10(1./aevms);

bar(snr);
xlabel('Data Symbol Index');
ylabel('average SNR(dB)');
title('average SNR(dB) of each subcarriers');

fprintf('average SNR(dB) of all the data subcarrier: %3.2f dB\n',10*log10(1./mean(evm_mat(:))));

%% bit error rate of each subcarrier
cf = cf + 1;
figure(cf); clf;

rx_data_mat = reshape(rx_data, length(SC_IND_DATA), N_OFDM_SYMS);
tx_data_mat = reshape(tx_data, length(SC_IND_DATA), N_OFDM_SYMS);
[numerrs,ratio] = biterr(tx_data_mat,rx_data_mat,[],'row-wise');

bar(ratio);
xlabel('Data Symbol Index');
ylabel('bit error rate');
title('bit error rate of each subcarrier');

%% Symbol constellation
cf = cf + 1;
figure(cf); clf;

plot(rx_syms(:),'r.','MarkerSize',1);
axis square; axis(1.5*[-1 1 -1 1]);
grid on;
hold on;

plot(rx_syms(find((tx_data ~= rx_data)==1)),'g.','MarkerSize',1);
title('Symbol Constellations');
legend('Correct','Erroneous','Location','EastOutside');

%% Calculate throughput

throughput = (N_DATA_SYMS * log2(MOD_ORDER) - sum(numerrs)) / (N_OFDM_SYMS*4e-6);
fprintf('throughput: %d\n', throughput);

%% throughput of each modulation
cf = cf + 1;
figure(cf); clf;

x = [2 4 16 64];
y = [12000000 23998500 throughput 64072500];

bar(x,y);
xlabel('modulation');
ylabel('throughput');
title('throughput of each modulation');

fprintf('optimal modulation 64AQM throughput: %d\n', 64072500);