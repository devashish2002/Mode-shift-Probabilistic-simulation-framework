clear
warning('OFF', 'MATLAB:table:ModifiedAndSavedVarnames')
%format longEng
%digits(100000000)

data = readtable('trip_data_c2smart_before_fhv.csv', 'HeaderLines',0);

%% zone: number of taxi zones, group: income groups, mode: number of modes 
zone = 263;
group = 16;
mode = 4;
modecode = [2, 3, 5, 8];

%% 1 Carpool; 2 Transit; 3 Taxi; 4 Bike; 5 Walk; 6 FHV; 7 CitiBike; 8 Driving

% time

travelTime = zeros(zone, zone, mode)-1;

for i = 1:mode
    time = data(data.tmode==modecode(i), [1 2 4]);
    time = time{:,:};
    %if i ==3
    %    time(:, 3) = time(:, 3) * 1.055;
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
    %if i ==2
    %    cost(:, 3) = cost(:, 3) * 1.3;
    %end
    for j = 1:size(cost, 1)
        travelCost(cost(j,1), cost(j,2), i) = cost(j, 3);
    end
end

travelCost(travelCost == -1) = inf;


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

%% Simulation with different lambda and beta values

iterA = 20;
iterB = 20;
goodness = zeros(iterA, iterB);

aa1 = 15;
bb1 = 2;
aa2 = 10;
bb2 = 2;

all_lambda = [0.025:0.0025:0.18]; % [0.025:0.002:0.08];
all_beta = [0.35:0.035:1.8]; % [0.35:0.02:0.8];

tic; 
for p = 1:1:iterA
    for q = 1:1:iterB
        
        % utility function: -(lambda * wage * time + beta * cost)
        %lambda = (p/aa1)^bb1;
        %beta = (q/aa2)^bb2; 
        lambda = all_lambda(p);
        beta = all_beta(q);

        wage = [10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000, 50000, ...
            60000, 75000, 100000, 125000, 150000, 200000, 250000];
        wage = wage./ (30*24*60);
        %wage = wage./ 170;


        % exponential utility
        
        travelUtilityExp = zeros(zone, zone, group, mode)-1;
        
        for i = 1:group
            for j=1:mode
                [row,col] = find(travelTime(:, :, j)<inf);
                for k = 1:size(row)
                    travelUtilityExp(row(k), col(k), i, j) = exp(-(lambda .* wage(i) .* travelTime(row(k), col(k), j) + beta .* travelCost(row(k), col(k), j)));
                end
            end
        end
        
        %travelUtilityExp(travelUtilityExp == -1) = -inf;
                
        % Mode split

        % probability of choice

        travelProbability = zeros(zone, zone, group, mode)-1;

        for i = 1:group
            totalUtilityExp = zeros(zone, zone);
            for j = 1:mode
                [row,col] = find(travelUtilityExp(:, :, i, j) >=0);
                for k = 1:size(row)
                    totalUtilityExp(row(k), col(k)) = totalUtilityExp(row(k), col(k)) + travelUtilityExp(row(k), col(k), i, j);
                end
            end
            [row,col] = find(totalUtilityExp(:, :)>=0);
            for k = 1:size(row)
                for j = 1:mode
                    if travelUtilityExp(row(k), col(k), i, j) >0
                        travelProbability(row(k), col(k), i, j) =  travelUtilityExp(row(k), col(k), i, j)./totalUtilityExp(row(k), col(k));
                    elseif travelUtilityExp(row(k), col(k), i, j) == 0 
                        travelProbability(row(k), col(k), i, j) = 0;
                    end
                end
            end
        end


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

        % Validation

        % real data

        valid = readtable('trip_data_c2smart_before_fhv_validation.csv', 'HeaderLines',0);
        %valid = valid{:, :};

        modecode = [2, 3, 5, 8];
        
        travelRealFlow = zeros(zone, zone, group, mode)-1;
        similarity = zeros(1, group*mode);
        ccount = 0;
        
        TT = zeros(1, mode);
        YT = zeros(1, mode);
        for i = 1:mode
            rtrip = valid(valid.tmode == modecode(i), [1, 2, 6:(group+5)]);
            rtrip = rtrip{:, :};
            for j =1:group
                for k = 1:size(rtrip, 1)
                    travelRealFlow(rtrip(k,1), rtrip(k,2), j, i) = rtrip(k, 2+j);
                end
                
                 T = travelRealFlow(:, :, j, i);
                 Y = travelSplitFlow(:, :, j, i);

                [R,P] = corrcoef(T(:), Y(:));

                similarity((i-1)*group + j) =  R(1,2);

                TT(i) = TT(i) + sum(sum(T));
                YT(i) = YT(i) + sum(sum(Y));
            end
        end
        
        E = (TT - YT);
        %[R,P] = corrcoef(TT(:), YT(:));
        
        %goodness(p, q) = R(1,2) + mean(similarity);
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

best_lambda =  all_lambda(x); %(x/aa1)^bb1;
best_beta = all_beta(y); %(y/aa2)^bb2;

XX = zeros(iterA, iterB);
YY = zeros(iterA, iterB);
ZZ = zeros(iterA, iterB);
for p = 1:1:iterA
    for q = 1:1:iterB
        XX(p, q) = all_lambda(p); % (p/aa1)^bb1;
        YY(p, q) = all_beta(q); %(q/aa2)^bb2;
        ZZ(p, q) = goodness(p, q);
    end
end

contourf(XX,YY,ZZ,20,'-'); hold on
plot(best_lambda, best_beta, 'r+');
colorbar;
xlim([0.01, 0.1]);
ylim([0.1, 1]);
%set(gca, 'xtick', [0:0.001:0.004]);
%set(gca, 'xticklabel', [0:0.001:0.004]);
xlabel('lambda')
ylabel('beta')