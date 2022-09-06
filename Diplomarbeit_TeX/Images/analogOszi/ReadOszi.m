%% == setup ==
close all;
pkg load instrument-control;

%% == configuration ==
title = 'example';
serialPort = "/dev/tty.usbserial5";

% Oszi Settings
channel = 3;
tPerDiv = 5E-3;
vPerDiv = [.2 .2];

% Smooth data
moveMeanF = [0 0];

% Output eps and csv
fileOut = true;

% Oszi Values
xDivs = 10;
yDivs = 8;
yPtPerDiv = 28;
xPtPerDiv = 100;

%% == Initialisation ==

% Time Vector
time = linspace(0, xDivs * tPerDiv, 2048);

data = [];

if !exist('cal')
  cal = [];
  genCalib = true;
  disp('Calibrate Oszis');
else
  genCalib = false;
endif

% If no Channel from first serial Port is selected
%if !bitand(bitshift(channel, -2 * (i-1)), 3)
%  continue
%endif

% Open serial port
disp('Connect to Serial');
s = serial(serialPort); % path, baudrate, timeout

% Wait for it 1s
pause(1);

% Configure serial communication
set(s, 'bytesize', 8);
set(s, 'parity', 'n');
set(s, 'stopbits', 1);
set(s, 'baudrate', 9600);
set(s, 'timeout', 10);

% Wait for it 1s
pause(1);

% Flush serial memory
disp('Flush serial memory');
srl_flush(s);

% Wait for it 1s
pause(1);

% Write request to Oszi
disp('Write request to oszi');
srl_write(s, "DIG\textbackslash r");
disp('Read first 2048 bits from oszi');
data1 = srl_read(s, 2048);
disp('Read second 2048 bits from oszi');
data2 = srl_read(s, 2048);

% Close serial connection
disp('Close serialport');
% fclose(s);

% If no calibration is generated, generate one
if genCalib
  cal = [cal; sum(int16(data1) - 128)/length(data1)];
  cal = [cal; sum(int16(data2) - 128)/length(data2)];
  return;
end
  
data1 = (double(int16(data1) - 128 - cal(1)) / yPtPerDiv) / (1/vPerDiv(1));
data2 = (double(int16(data2) - 128 - cal(2)) / yPtPerDiv) / (1/vPerDiv(2));

if moveMeanF(1) > 1
  data1 = movmean(data1, moveMeanF(1));
endif
if moveMeanF(2) > 1
  data2 = movmean(data2, moveMeanF(2));
endif

data = [data; data1];
data = [data; data2];

f = figure;
out = time';

% Time Unit
unitTm = 1;
unitT = 's';

% Scale time
if max(time) < 1E-6
  unitT = 'ns';
  unitTm = 1E9;
elseif max(time) < 1E-3 || min(time) > 1E-3
  unitT = '\mus';
  unitTm = 1E6;
elseif max(time) < 1E1
  unitT = 'ms';
  unitTm = 1E3;
end

% Voltage Unit
unitVm = 1;
unitV = 'V';

% Scale Y
if max(max(data)) < 1E-3
  unitV = '\muV';
  unitVm = 1E6;
elseif max(max(data)) < 1E0
  unitV = 'mV';
  unitVm = 1E3;
end

% Only plot selected Channels
disp('Plot');
for i = 1:size(data)(1)
  if bitand(channel, i)
    out = [out, data(i,:)'];
    plot(time * unitTm, data(i,:) * unitVm);
    hold on
  end
end

grid on
xlabel(sprintf('t in %s', unitT))
ylabel(sprintf('U in %s', unitV))

ylim([min(min(data))*unitVm*1.1, max(max(data)) * unitVm*1.1])

if fileOut 
  disp('Save to Files');
  mkdir(title); % Create a new dir for measure
  %saveas(f, sprintf('%s/%s',title, title), 'epsc'); % For windows
  print(f,'-depsc','-painters',sprintf('%s/%s.eps', title, title)); % For MAC
  csvwrite(sprintf('%s/%s.csv', title, title), out);
end
