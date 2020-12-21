clear
warning('OFF', 'MATLAB:table:ModifiedAndSavedVarnames')
%format longEng
%digits(100000000)


data = readtable('trip_data_c2smart_after_fhv_updated.csv', 'HeaderLines',0);
%data = data{:, :};

%% zone: number of taxi zones, group: income groups, mode: number of modes 
zone = 263;
group = 16;
mode = 6;
modecode = [1, 2, 3, 4, 5, 6];

%% %% 1 Taxi; 2 FHV; 3 shared FHV; 4 Public Transit; 5 Walking; 6 Private Car

% time

travelTime = zeros(zone, zone, mode)-1;

for i = 1:mode
    time = data(data.tmode==modecode(i), [1 2 4]);
    time = time{:,:};
    if i ==5
        time(:, 3) = time(:, 3) * 1.055;
    end
    %if i ==3
    %    time(:, 3) = time(:, 3) * 2.1;
    %end
    for j = 1:size(time, 1)
        travelTime(time(j,1), time(j,2), i) = time(j, 3);
    end
end

travelTime(travelTime == -1) = inf;

% cost

travelCost = zeros(zone, zone, mode)-1;

for i = 1:mode
    cost = data(data.tmode==modecode(i), [1 2 5]);
    cost = cost{:,:};
    if (i == 1) %|| (i == 2) || (i == 3)
        cost(:, 3) = cost(:, 3) * 1.3;
    end
    for j = 1:size(cost, 1)
        travelCost(cost(j,1), cost(j,2), i) = cost(j, 3);
    end
end

travelCost(travelCost == -1) = inf;

%% wage groups
%% w10000, w15000, w20000, w25000, w30000, w35000, w40000, w45000, w50000,
%% w60000, w75000, w100000, w125000, w150000, w200000, w250000

% trip

[~,ia] = unique(data(:, [1 2]));
trip = data(ia,[1 2, 6:(group+5)]);
trip = trip{:, :};

travelFlow = zeros(zone, zone, group)-1;

for i = 1:group
    for j = 1:size(trip, 1)
        travelFlow(trip(j,1), trip(j,2), i) = trip(j, 2+i);
    end
end

travelFlow(travelFlow == -1) = -inf;

%% Simulation: different interations of lambda, beta, tau1 and tau2

iterA = 10;
iterB = 10;
goodness = zeros(iterA, iterB);

aa1 = 5;
bb1 = 4;
aa2 = 10;
bb2 = 3;

lambda = 0.0385;
beta = 0.51;

all_tau_1 = [0.1:0.2:100.5]; %[1:2:100.5]; % [0.1:0.2:100.5];
all_tau_2 = [0.1:0.1:1.5];

tic;
for p = 2 %1:1:iterA
    for q = 2 % 1:1:iterB
        
        % utility function: -(lambda * wage * time + beta * cost)
        %tau_1 = (p/aa1)^bb1;
        %tau_2 = (q/aa2)^bb2;
        tau_1 = all_tau_1(p);
        tau_2 = all_tau_2(q);
        
        wage = [10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000, 50000, ...
            60000, 75000, 100000, 125000, 150000, 200000, 250000];
        wage = wage./ (30*24*60);
        
        % exponential utility
        
        travelUtilityExp = zeros(zone, zone, group, mode)-1;
        
        for i = 1:group
            for j=1:mode
                [row,col] = find(travelTime(:, :, j)<inf);
                for k = 1:size(row)
                    travelUtilityExp(row(k), col(k), i, j) = exp(-(lambda * wage(i) * travelTime(row(k), col(k), j) + beta * travelCost(row(k), col(k), j)));
                end
            end
        end
        
        %travelUtilityExp(travelUtilityExp == -1) = -inf;
        
        % Mode split
        
        % probability of choice
        
        travelProbability = zeros(zone, zone, group, mode);
        travelFHVUtilityExp = zeros(zone, zone, group);
        travelCarUtilityExp = zeros(zone, zone, group);
        totalUtilityExp = zeros(zone, zone, group);
        
        for i = 1:group
            % FHV, sharedFHV nest
            for j = 2:3
                [row,col] = find(travelUtilityExp(:, :, i, j) >=0);
                for k = 1:size(row)
                    travelFHVUtilityExp(row(k), col(k), i) = travelFHVUtilityExp(row(k), col(k), i) + travelUtilityExp(row(k), col(k), i, j)^(tau_2);
                end
            end
            [row,col] = find(travelFHVUtilityExp(:, :, i) >=0);
            for k = 1:size(row)
                travelFHVUtilityExp(row(k), col(k), i) = exp(log(travelFHVUtilityExp(row(k), col(k), i))/tau_2);
            end
            
            % Taxi, FHV nest
            for j = 1
                [row,col] = find(travelUtilityExp(:, :, i, j) >=0);
                for k = 1:size(row)
                    travelCarUtilityExp(row(k), col(k), i) = travelCarUtilityExp(row(k), col(k), i) + travelUtilityExp(row(k), col(k), i, j)^(tau_1);
                end
            end
            [row,col] = find(travelFHVUtilityExp(:, :, i) >=0);
            for k = 1:size(row)
                travelCarUtilityExp(row(k), col(k), i) = travelCarUtilityExp(row(k), col(k), i) + travelFHVUtilityExp(row(k), col(k), i)^(tau_1);
            end
            [row,col] = find(travelCarUtilityExp(:, :, i) >=0);
            for k = 1:size(row)
                travelCarUtilityExp(row(k), col(k), i) = exp(log(travelCarUtilityExp(row(k), col(k), i))/tau_1);
            end
            
            for j = 4:mode
                [row,col] = find(travelUtilityExp(:, :, i, j) >=0);
                for k = 1:size(row)
                    totalUtilityExp(row(k), col(k), i) = totalUtilityExp(row(k), col(k), i) + travelUtilityExp(row(k), col(k), i, j);
                end
            end
            [row,col] = find(travelCarUtilityExp(:, :, i) >=0);
            for k = 1:size(row)
                totalUtilityExp(row(k), col(k), i) = totalUtilityExp(row(k), col(k), i) + travelCarUtilityExp(row(k), col(k), i);
            end
        end
        
        travelCarUtilityExp(travelCarUtilityExp == 0) = -1;
        travelFHVUtilityExp(travelFHVUtilityExp == 0) = -1;
        totalUtilityExp(totalUtilityExp == 0) = -1;
        
        for i = 1:group
            
            [row,col] = find(totalUtilityExp(:, :, i)>0);
            for k = 1:size(row)
                for j = 1
                    if travelUtilityExp(row(k), col(k), i, j) >0
                        travelProbability(row(k), col(k), i, j) = (travelUtilityExp(row(k), col(k), i, j)^(tau_1))/...
                            (travelCarUtilityExp(row(k), col(k), i)^(tau_1))* ...
                            travelCarUtilityExp(row(k), col(k), i)/totalUtilityExp(row(k), col(k), i);
                    elseif travelUtilityExp(row(k), col(k), i, j) == 0
                        travelProbability(row(k), col(k), i, j) = 0;
                    end
                end
                
                for j = 2:3
                    if travelUtilityExp(row(k), col(k), i, j) >0
                        travelProbability(row(k), col(k), i, j) = (travelUtilityExp(row(k), col(k), i, j)^(tau_2))/...
                            (travelFHVUtilityExp(row(k), col(k), i)^(tau_2))* ...
                            (travelFHVUtilityExp(row(k), col(k), i)^(tau_1))/...
                            (travelCarUtilityExp(row(k), col(k), i)^(tau_1))* ...
                            travelCarUtilityExp(row(k), col(k), i)/totalUtilityExp(row(k), col(k), i);
                    elseif travelUtilityExp(row(k), col(k), i, j) == 0
                        travelProbability(row(k), col(k), i, j) = 0;
                    end
                end
                
                for j = 4:mode
                    if travelUtilityExp(row(k), col(k), i, j) >0
                        travelProbability(row(k), col(k), i, j) =  travelUtilityExp(row(k), col(k), i, j)/totalUtilityExp(row(k), col(k), i);
                    elseif travelUtilityExp(row(k), col(k), i, j) == 0
                        travelProbability(row(k), col(k), i, j) = 0;
                    end
                end
            end
        end
        
        %travelProbability(travelProbability == -1) = -inf;
        %travelProbability(isnan(travelProbability))=1;
        
        % predicted trips
        
        travelSplitFlow = zeros(zone, zone, group, mode)-1;
        
        for i = 1: group
            [row,col] = find(travelFlow(:, :, i)>=0);
            for k = 1:size(row)
                for j = 1:mode
                    if travelProbability(row(k), col(k), i, j) >=0
                        travelSplitFlow(row(k), col(k), i, j) = travelFlow(row(k), col(k), i) .* travelProbability(row(k), col(k), i, j);
                    end
                end
            end
        end
        
        %travelSplitFlow(travelSplitFlow == -1) = -inf;
        
        travelSplitRatio = zeros(zone, zone, 3);
        tmp = sum(travelSplitFlow, 3);
        for i = 1:3
            [row,col] = find(tmp(:, :, 1, i)>=0);
            for k = 1:size(row)
                travelSplitRatio(row(k), col(k), i) = tmp(row(k), col(k), 1, i);
            end
        end
        
        ttmp = zeros(zone, zone);
        for i = 1:3
            [row,col] = find(travelSplitRatio(:, :, i)>=0);
            for k = 1:size(row)
                ttmp(row(k), col(k)) =ttmp(row(k), col(k)) + travelSplitRatio(row(k), col(k), i);
            end
        end
        
        for i = 1:3
            [row,col] = find(ttmp(:, :)>0);
            for k = 1:size(row)
                travelSplitRatio(row(k), col(k), i) =travelSplitRatio(row(k), col(k), i)/ttmp(row(k), col(k));
            end
        end
        
        travelSplitRatio(isnan(travelSplitRatio))=0;
        
        % Validation
        
        % real data
        
        valid = readtable('trip_data_tlc_after_fhv_validation.csv', 'HeaderLines',0);
        %valid = valid{:, :};
        allvalid = valid{:, :};
        totalvalid = sum(allvalid(:, 4));
        
        travelRealRatio = zeros(zone, zone, 3);
        similarity = zeros(1, 3);
        ccount = 0;
        
        for i = 1:3
            rtrip = valid(valid.tmode == modecode(i), [1, 2, 4]);
            rtrip = rtrip{:, :};
            rtrip = rtrip(((rtrip(:,1)<=263)&(rtrip(:,2)<=263)), :);
            
            for k = 1:size(rtrip, 1)
                travelRealRatio(rtrip(k,1), rtrip(k,2), i) = rtrip(k, 3);
            end
        end
        
        tttmp = zeros(zone, zone);
        for i = 1:3
            [row,col] = find(travelRealRatio(:, :, i)>=0);
            for k = 1:size(row)
                tttmp(row(k), col(k)) =tttmp(row(k), col(k)) + travelRealRatio(row(k), col(k), i);
            end
        end
        
        for i = 1:3
            [row,col] = find(tttmp(:, :)>0);
            for k = 1:size(row)
                travelRealRatio(row(k), col(k), i) =travelRealRatio(row(k), col(k), i)/tttmp(row(k), col(k));
            end
        end
        
        TT = zeros(1, 3);
        YT = zeros(1, 3);
        for i = 1:3
            T = travelRealRatio(:, :, i);
            Y = travelSplitRatio(:, :, i);            

            [R,P] = corrcoef(T(:), Y(:));
            
            similarity(i) =  R(1,2);
            
            TT(i) = TT(i) + sum(sum(travelRealRatio(:, :, i) .* tttmp(:, :)));
            YT(i) = YT(i) + sum(sum(travelSplitRatio(:, :, i) .* ttmp(:, :)));
                
        end
        
        TT = TT/sum(TT);
        YT = YT/sum(YT);
        E = (TT - YT);
        
        goodness(p, q) = mean(similarity) - sum(abs(E)./TT); 

    end
end

toc

%%  plot error

fig = figure;
set(gcf, 'units','centimeters', 'OuterPosition', [0 0 9.3 7.3], 'Position', [0 0 18.3 7.3]);
set(gcf, 'color', 'white');box on
set(gca, 'ticklength', [0.02 0.02]);
set(gca,'XMinorTick','on','YMinorTick','on')
set(gca, 'fontsize', 12);

%imagesc(goodness);

A = goodness;
maximum = max(max(A));
[x,y]=find(A==maximum);

best_tau_1 = all_tau_1(x); %(x/aa1)^bb1;
best_tau_2 = all_tau_2(y); % (y/aa2)^bb2;

XX = zeros(iterA, iterB);
YY = zeros(iterA, iterB);
ZZ = zeros(iterA, iterB);
for p = 1:1:iterA
    for q = 1:1:iterB
        XX(p, q) = all_tau_1(p); % (p/aa1)^bb1;
        YY(p, q) = all_tau_2(q); % (q/aa2)^bb2;
        ZZ(p, q) = goodness(p, q);
    end
end

contourf(XX,YY,ZZ,20,'-'); hold on
plot(best_tau_1, best_tau_2, 'r+');
colorbar;
%xlim([0, 10]);
%ylim([0, 10]);
%set(gca, 'xtick', [0:0.001:0.004]);
%set(gca, 'xticklabel', [0:0.001:0.004]);
xlabel('tau 1')
ylabel('tau 2')