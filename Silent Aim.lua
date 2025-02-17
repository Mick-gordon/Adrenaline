repeat task.wait(); until game:IsLoaded();

-- // Variables
local Players = game:GetService("Players");
local LocalPlayer = Players.LocalPlayer;
local CurrentCamera = game:GetService("Workspace").CurrentCamera;
local UserInputService = game:GetService("UserInputService");
local RunService = game:GetService("RunService");
local HttpService = game:GetService("HttpService");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Environment = getexecutorname and string.lower(getexecutorname());


-- // Constants
local Gravity = Vector3.new(0, 192, 0); -- For The Bullets!


-- // Tables
local Drawings = { };
local SilentAim = {   
    Enabled = false,
    HitPart = "Head",
    Prediction = true, -- If You Ever Don't Want It For Some Reason.
    PenCheck = false,
    
    Fov = { 
        Visible = false,
        Radius = 600
    },

    ----
    Keybind = "RightShift"; -- For UI
};


-- // Module
if Environment and string.match(Environment, "xeno") then
    return LocalPlayer:Kick("Xeno Is Not Supported, Executor Must Have Drawing and hookfunction And require Or getgc."); -- No Idea If This Shitty External Sill Lives.
end;

local Success, BulletHandler = pcall(require, ReplicatedStorage.Modules.Client.Handlers.BulletHandler);   
if (not Success and not getgc) or not hookfunction or not Drawing then
    return LocalPlayer:Kick("Executor Is Not Supported, Executor Must Have Drawing and hookfunction And require Or getgc.");

elseif not Success and getgc then -- Some Executors Have getgc But Cant require ?
    BulletHandler = nil;
    for _, Function in getgc() do
        if typeof(Function) == "function" and debug.info(Function, "n") == "" and debug.info(Function, "l") == 250 then 
            BulletHandler = Function;
            break;
        end;
    end;
    
    if not BulletHandler then
        return LocalPlayer:Kick("Executor Is Not Supported, Executor Must Have Drawing and hookfunction And require Or getgc.");
    end;

end;

local Success, BulletSimulator = pcall(require, ReplicatedStorage.Modules.Shared.Classes.BulletSimulator);
if Success and debug.getconstant and typeof(debug.getconstant(BulletSimulator.Update, 6)) == "number" then
    Gravity = Vector3.new(0, debug.getconstant(BulletSimulator.Update, 6), 0);
end;


-- // Functions
local Functions = { };
do
    
    function Functions:IsAlive(Player)
        if Player and Player.Character and Player.Character:GetAttribute("Health") > 0 and Player.Character:GetAttribute("State") == "Alive" then
            return true;
        end;
        return false;
    end;
    
    function Functions:GetTarget(Origin, Weapon_Data, Ignore)
        local Closest, HitBox = (SilentAim.Fov.Radius == 0 and math.huge) or SilentAim.Fov.Radius, nil;
        
        for _,Player in Players:GetChildren() do

            if Player == LocalPlayer then
                continue;
            end;
            
            if Player.Team == LocalPlayer.Team then
                continue;
            end;
            
            if not Functions:IsAlive(Player) then
                continue;
            end;
            
            local HitPart = Player.Character:FindFirstChild(SilentAim.HitPart);
            if not HitPart then
                continue;
            end;
            
            local ScreenPosition, OnScreen = CurrentCamera:WorldToViewportPoint(HitPart.Position);
            local Distance = (UserInputService:GetMouseLocation() - Vector2.new(ScreenPosition.X, ScreenPosition.Y)).Magnitude;
            
            if (SilentAim.Fov.Radius ~= 0 and not OnScreen) or (SilentAim.Fov.Radius == 0 and ScreenPosition.Z <= 0) then
                continue;
            end;

            if SilentAim.PenCheck and not Functions:PenCheck(Origin, HitPart, Weapon_Data.Source.Penetration, table.unpack(Ignore)) then 
                continue;
            end;
            
            if Distance < Closest then
                Closest = Distance;
                HitBox = HitPart;
            end;
            
        end;
        
        return HitBox;
    end;

    function Functions:SolveQuadratic(A, B, C)
        local Discriminant = B^2 - 4*A*C;
        if Discriminant < 0 then
            return nil, nil;
        end;
    
        local DiscRoot = math.sqrt(Discriminant);
        local Root1 = (-B - DiscRoot) / (2*A);
        local Root2 = (-B + DiscRoot) / (2*A);
        
        return Root1, Root2;
    end;

    function Functions:CalCulateBallisticFlightTime(Direction, MuzzleVelovity)
        local Root1, Root2 = Functions:SolveQuadratic(
            Gravity:Dot(Gravity) / 4,
            Gravity:Dot(Direction) - MuzzleVelovity^2,
            Direction:Dot(Direction)
        );
    
        if Root1 and Root2 then
            if Root1 > 0 and Root1 < Root2 then
                return math.sqrt(Root1);
            elseif Root2 > 0 and Root2 < Root1 then
                return math.sqrt(Root2);
            end;
        end;
        
        return 0;
    end;

    function Functions:CalCulateBulletDrop(To, From, MuzzleVelovity) 
        local Time = Functions:CalCulateBallisticFlightTime(To - From, MuzzleVelovity);
        local Vertical = 0.5 * Gravity * Time^2; 
        
        return Vertical;
    end;

    function Functions:Predict(Target, From, MuzzleVelovity)
        local Time = Functions:CalCulateBallisticFlightTime(Target.Position - From, MuzzleVelovity);

        return Target.Position + (Target.Velocity * Time);
    end;

    function Functions:GetWalls(Origin, Target, ...) -- TODO: Make This Non Linear and PenCheck.
        local Ignore = {CurrentCamera, ...};
        local Walls = { };

        local NoMoreWalls = false;
        
        local function AddWall()
            local Hit = workspace:FindPartOnRayWithIgnoreList(Ray.new(Origin, Target.Position - Origin), Ignore, false, true);
            if Hit and Hit:IsDescendantOf(Target.Parent) then
                NoMoreWalls = true;
                return;
            elseif Hit then
                Walls[#Walls + 1] = Hit;
                Ignore[#Ignore + 1] = Hit;
            end;
        end;

        repeat AddWall() until NoMoreWalls;

        return Walls;
    end;

    function Functions:PenCheck(Origin, Target, PenDepth, ...) 
        local Ignore = {CurrentCamera, ...};
        local Direction = Target.Position - Origin;
        local IsVisible = workspace:FindPartOnRayWithIgnoreList(Ray.new(Origin, Direction), Ignore, false, true);

        if IsVisible and IsVisible:IsDescendantOf(Target.Parent) then
            return true;
        end;
        
        local Penetrated = 0;
        for _, Wall in Functions:GetWalls(Origin, Target, ...) do
            if Wall.CanCollide and Wall.Transparency ~= 1 then
                local MaxExtent = Wall.Size.Magnitude * Direction.Unit;
                local _, Enter = workspace:FindPartOnRayWithWhitelist(Ray.new(Origin, Direction), {Wall}, true)
                local _, Exit = workspace:FindPartOnRayWithWhitelist(Ray.new(Enter + MaxExtent, -MaxExtent), {Wall}, true)
                local Depth = (Exit - Enter).Magnitude;

                if Depth > PenDepth then
                    return false;
                else
                    Penetrated += Depth;
                end;
            end;
        end;
        
        return Penetrated < PenDepth;
    end;

    function Functions:Draw(Type, Properties)
        local Drawing = Drawing.new(Type);

        for Prop, Value in Properties do
            Drawing[Prop] = Value;
        end;

        Drawings[#Drawings + 1] = Drawing;
        return Drawing;
    end;

    function Functions:IsMouseOver(Drawing)
        if UserInputService:GetMouseLocation().X >= Drawing.Position.X and UserInputService:GetMouseLocation().Y >= Drawing.Position.Y then
            if UserInputService:GetMouseLocation().X <= Drawing.Position.X + Drawing.Size.X and UserInputService:GetMouseLocation().Y <= Drawing.Position.Y + Drawing.Size.Y then
                return true;
            end;
        end;

        return false;
    end;

end;

-- // Hooks
do

    local Old; Old = hookfunction(BulletHandler, function(Origin, LookVector, p33, Weapon_Data, Ignore, Is_Local_Platers_Bullet, Tick)
            
        if not Is_Local_Platers_Bullet or not SilentAim.Enabled then
            return Old(Origin, LookVector, p33, Weapon_Data, Ignore, Is_Local_Platers_Bullet, Tick);
        end;

        local Target = Functions:GetTarget(Origin, Weapon_Data, Ignore);
        if not Target then
            return Old(Origin, LookVector, p33, Weapon_Data, Ignore, Is_Local_Platers_Bullet, Tick);
        end;

        local TargtePosition = SilentAim.Prediction and Functions:Predict(Target, Origin, Weapon_Data.Source.MuzzleVelocity) or (not SilentAim.Prediction and Target.Position);
        local VerticalDrop = Functions:CalCulateBulletDrop(Origin, TargtePosition, Weapon_Data.Source.MuzzleVelocity);
        
        LookVector = (TargtePosition + VerticalDrop - Origin).Unit;

        return Old(Origin, LookVector, p33, Weapon_Data, Ignore, Is_Local_Platers_Bullet, Tick);
    end);

end;

-- // GUI
do

    -- // GUI (I Made It External If The Drawing Libary Is In C++. (I Thought It Would Be Fun.))
    local ListYSize = 25; -- Yes I Could Of Used A UI Lib Or Made One But I Am .420% Sigma.
    local Background = Functions:Draw("Square", {Visible = true, Filled = true, Color = Color3.fromRGB(52, 52, 52), Size = Vector2.new(241, 248), Position = CurrentCamera.ViewportSize/2 - Vector2.new(241, 248)/2, Transparency = 1, ZIndex = 10}); -- ZIndex Is At 10 Just Incase You Are Using ESP.
    local Outline = Functions:Draw("Square", {Visible = true, Filled = false, Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Size = Background.Size, Position = Background.Position, Transparency = 1, ZIndex = 10});
    local Enable = Functions:Draw("Square", {Visible = true, Filled = true, Color = Color3.fromRGB(52, 52, 52), Size = Vector2.new(122, 24), Position = Background.Position + Vector2.new(Background.Size.X/2 - 61, ListYSize), Transparency = 1, ZIndex = 10}); ListYSize = ListYSize + 29;
    local EnableText = Functions:Draw("Text", {Visible = true, Size = 17, Center = true, Position = Enable.Position + Enable.Size/2 - Vector2.new(0, 8.5), Text = "Enable", Color = Color3.fromRGB(255, 255, 255), Font = 0, ZIndex = 10, Outline = false}); 
    local EnableOutline = Functions:Draw("Square", {Visible = true, Filled = false, Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Size = Enable.Size, Position = Enable.Position, Transparency = 1, ZIndex = 10});
    local PenCheck = Functions:Draw("Square", {Visible = true, Filled = true, Color = Color3.fromRGB(52, 52, 52), Size = Vector2.new(122, 24), Position = Background.Position + Vector2.new(Background.Size.X/2 - 61, ListYSize), Transparency = 1, ZIndex = 10}); ListYSize = ListYSize + 29;
    local PenCheckText = Functions:Draw("Text", {Visible = true, Size = 17, Center = true, Position = PenCheck.Position + PenCheck.Size/2 - Vector2.new(0, 8.5), Text = "Pen Check", Color = Color3.fromRGB(255, 255, 255), Font = 0, ZIndex = 10, Outline = false}); 
    local PenCheckOutline = Functions:Draw("Square", {Visible = true, Filled = false, Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Size = PenCheck.Size, Position = PenCheck.Position, Transparency = 1, ZIndex = 10});
    local Prediction = Functions:Draw("Square", {Visible = true, Filled = true, Color = Color3.fromRGB(2, 54, 8), Size = Vector2.new(122, 24), Position = Background.Position + Vector2.new(Background.Size.X/2 - 61, ListYSize), Transparency = 1, ZIndex = 10}); ListYSize = ListYSize + 29;
    local PredictionText = Functions:Draw("Text", {Visible = true, Size = 17, Center = true, Position = Prediction.Position + Prediction.Size/2 - Vector2.new(0, 8.5), Text = "Prediction", Color = Color3.fromRGB(255, 255, 255), Font = 0, ZIndex = 10, Outline = false}); 
    local PredictionOutline = Functions:Draw("Square", {Visible = true, Filled = false, Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Size = Prediction.Size, Position = Prediction.Position, Transparency = 1, ZIndex = 10});
    local ShowFov = Functions:Draw("Square", {Visible = true, Filled = true, Color = Color3.fromRGB(52, 52, 52), Size = Vector2.new(122, 24), Position = Background.Position + Vector2.new(Background.Size.X/2 - 61, ListYSize), Transparency = 1, ZIndex = 10}); ListYSize = ListYSize + 29;
    local ShowFovText = Functions:Draw("Text", {Visible = true, Size = 17, Center = true, Position = ShowFov.Position + ShowFov.Size/2 - Vector2.new(0, 8.5), Text = "Show Fov Circle", Color = Color3.fromRGB(255, 255, 255), Font = 0, ZIndex = 10, Outline = false});
    local ShowFovOutline = Functions:Draw("Square", {Visible = true, Filled = false, Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Size = ShowFov.Size, Position = ShowFov.Position, Transparency = 1, ZIndex = 10});
    local FovRadiusText = Functions:Draw("Text", {Visible = true, Size = 17, Center = true, Position = Background.Position + Vector2.new(Background.Size.X/2, ListYSize + 1.5), Text = "Fov Radius", Color = Color3.fromRGB(255, 255, 255), Font = 0, ZIndex = 10, Outline = false}); ListYSize = ListYSize + 25;
    local FovRadiusBackround = Functions:Draw("Square", {Visible = true, Filled = true, Color = Color3.fromRGB(52, 52, 52), Size = Vector2.new(122, 24), Position = Background.Position + Vector2.new(Background.Size.X/2 - 61, ListYSize), Transparency = 1, ZIndex = 10}); ListYSize = ListYSize + 29;
    local FovRadius = Functions:Draw("Square", {Visible = true, Filled = true, Color = Color3.fromRGB(100, 0, 255), Size = FovRadiusBackround.Size, Position = FovRadiusBackround.Position, Transparency = 1, ZIndex = 10});
    local FovRadiusNumber = Functions:Draw("Text", {Visible = true, Size = 17, Center = true, Position = FovRadiusBackround.Position + FovRadiusBackround.Size/2 - Vector2.new(0, 8.5), Text = "600", Color = Color3.fromRGB(255, 255, 255), Font = 0, ZIndex = 10, Outline = false});
    local FovRadiusOutline = Functions:Draw("Square", {Visible = true, Filled = false, Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Size = FovRadiusBackround.Size, Position = FovRadiusBackround.Position, Transparency = 1, ZIndex = 10});
    local HitScan = Functions:Draw("Square", {Visible = true, Filled = true, Color = Color3.fromRGB(52, 52, 52), Size = Vector2.new(122, 24), Position = Background.Position + Vector2.new(Background.Size.X/2 - 61, ListYSize), Transparency = 1, ZIndex = 10}); ListYSize = ListYSize + 29;
    local HitScanText = Functions:Draw("Text", {Visible = true, Size = 17, Center = true, Position = HitScan.Position + HitScan.Size/2 - Vector2.new(0, 8.5), Text = "HEAD, torso", Color = Color3.fromRGB(255, 255, 255), Font = 0, ZIndex = 10, Outline = false});
    local HitScanOutline = Functions:Draw("Square", {Visible = true, Filled = false, Color = Color3.fromRGB(255, 255, 255), Thickness = 1, Size = HitScan.Size, Position = HitScan.Position, Transparency = 1, ZIndex = 10});
    local Name = Functions:Draw("Text", {Visible = true, Size = 16, Center = true, Position = Background.Position + Vector2.new(Background.Size.X/2, 15) - Vector2.new(0, 8.5), Text = "DELETEMOB | Adrenaline Silent Aim", Color = Color3.fromRGB(255, 255, 255), Font = 0, ZIndex = 10, Outline = false}); 
    local Discord = Functions:Draw("Text", {Visible = true, Size = 17, Center = true, Position = Background.Position + Vector2.new(Background.Size.X/2, Background.Size.Y - 25.5), Text = "https://discord.gg/FsApQ7YNTq", Color = Color3.fromRGB(255, 255, 255), Font = 0, ZIndex = 10, Outline = false}); 

    -- // Auto Load Config
    local function UpdateConfig()

    end;
    do

        if writefile and loadfile and isfile and makefolder then

            makefolder("DelteMob");
            makefolder("DelteMob/"..game.GameId);

            UpdateConfig = function()
                writefile("DelteMob/"..game.GameId.."/Config.json", HttpService:JSONEncode(SilentAim));
            end;

            if isfile("DelteMob/"..game.GameId.."/Config.json") then
                local Config = HttpService:JSONDecode(readfile("DelteMob/"..game.GameId.."/Config.json"));

                for i,v in Config do
                    SilentAim[i] = v;

                    if i == "Enabled" then
                        if not v then
                            Enable.Color = Color3.fromRGB(52, 52, 52);
                        else
                            Enable.Color = Color3.fromRGB(2, 54, 8);
                        end;
                    elseif i == "HitPart" then
                        if v == "Torso" then
                            HitScanText.Text = "head, TORSO";
                        else
                            HitScanText.Text = "HEAD, torso";
                        end;
                    elseif i == "Prediction" then
                        if not v then
                            Prediction.Color = Color3.fromRGB(52, 52, 52);
                        else
                            Prediction.Color = Color3.fromRGB(2, 54, 8);
                        end;
                    elseif i == "PenCheck" then
                        if not v then
                            PenCheck.Color = Color3.fromRGB(52, 52, 52);
                        else
                            PenCheck.Color = Color3.fromRGB(2, 54, 8);
                        end;
                    elseif i == "Fov" then
                        for i2, v2 in v do
                            if i2 == "Radius" then
                                FovRadiusNumber.Text = v2;
                                FovRadius.Size = Vector2.new(FovRadiusBackround.Size.X * (v2 / 600), FovRadius.Size.Y);
                            elseif i2 == "Visible" then
                                if not v2 then
                                    ShowFov.Color = Color3.fromRGB(52, 52, 52);
                                else
                                    ShowFov.Color = Color3.fromRGB(2, 54, 8);
                                end;
                            end;
                        end;
                    end;

                end;

            else
                UpdateConfig();
            end;


        end;

    end;

    -- // GUI Interactions
    local Dragging, StartPos, SliderDrag;
    UserInputService.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 and Background.Visible then
            if Functions:IsMouseOver(Background) and not Functions:IsMouseOver(FovRadiusBackround) then 
                Dragging = true;
                StartPos = UserInputService:GetMouseLocation();
            elseif Functions:IsMouseOver(FovRadiusBackround) then
                SliderDrag = true;
                local Ammount = (UserInputService:GetMouseLocation().X - FovRadiusBackround.Position.X) / FovRadiusBackround.Size.X;
                FovRadius.Size = Vector2.new(FovRadiusBackround.Size.X * Ammount, FovRadius.Size.Y);
                FovRadiusNumber.Text = math.floor(600 * Ammount);
                SilentAim.Fov.Radius = tonumber(FovRadiusNumber.Text);
                UpdateConfig();
            end
            if Functions:IsMouseOver(Enable) then
                if SilentAim.Enabled then
                    SilentAim.Enabled = false;
                    Enable.Color = Color3.fromRGB(52, 52, 52);
                else
                    SilentAim.Enabled = true;
                    Enable.Color = Color3.fromRGB(2, 54, 8);
                end;
                UpdateConfig();
            elseif Functions:IsMouseOver(PenCheck) then
                if SilentAim.PenCheck then
                    SilentAim.PenCheck = false;
                    PenCheck.Color = Color3.fromRGB(52, 52, 52);
                else
                    SilentAim.PenCheck = true;
                    PenCheck.Color = Color3.fromRGB(2, 54, 8);
                end;
                UpdateConfig();
            elseif Functions:IsMouseOver(ShowFov) then
                if SilentAim.Fov.Visible then
                    SilentAim.Fov.Visible = false;
                    ShowFov.Color = Color3.fromRGB(52, 52, 52);
                else
                    SilentAim.Fov.Visible = true;
                    ShowFov.Color = Color3.fromRGB(2, 54, 8);
                end;
                UpdateConfig();
            elseif Functions:IsMouseOver(HitScan) then
                if HitScanText.Text == "HEAD, torso" then
                    SilentAim.HitPart = "Torso"
                    HitScanText.Text = "head, TORSO";
                else
                    SilentAim.HitPart = "Head"
                    HitScanText.Text = "HEAD, torso";
                end;
                UpdateConfig();
            elseif Functions:IsMouseOver(Prediction) then
                if SilentAim.Prediction then
                    SilentAim.Prediction = false;
                    Prediction.Color = Color3.fromRGB(52, 52, 52);
                else
                    SilentAim.Prediction = true;
                    Prediction.Color = Color3.fromRGB(2, 54, 8);
                end;
                UpdateConfig();
            end;
        elseif Input.KeyCode == (Enum.KeyCode[SilentAim.Keybind] or Enum.KeyCode.RightShift) then
            if Background.Visible then
                for i = 1, #Drawings do
                    Drawings[i].Visible = false;
                end;
            else
                for i = 1, #Drawings do
                    Drawings[i].Visible = true;
                end;
            end;
        end;
    end);

    UserInputService.InputEnded:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then 
            Dragging = false;
            SliderDrag = false;
        end;
    end);

    UserInputService.InputChanged:Connect(function() 
        if Dragging and Background.Visible then
            local Distance = StartPos - UserInputService:GetMouseLocation();
            for i = 1, #Drawings do 
                Drawings[i].Position = Drawings[i].Position - Distance;
                StartPos = UserInputService:GetMouseLocation();
            end;
        elseif SliderDrag and Background.Visible and Functions:IsMouseOver(FovRadiusBackround) then
            local Ammount = (UserInputService:GetMouseLocation().X - FovRadiusBackround.Position.X) / FovRadiusBackround.Size.X; 
            FovRadius.Size = Vector2.new(FovRadiusBackround.Size.X * Ammount, FovRadius.Size.Y);
            FovRadiusNumber.Text = tostring(math.floor(600 * Ammount));
            SilentAim.Fov.Radius = tonumber(FovRadiusNumber.Text);
            UpdateConfig();
        end;
    end);

    -- // FOV
    do
        local Circle = Functions:Draw("Circle", {Visible = false, Filled = false, NumSides = 1000, Color = Color3.fromRGB(255, 255 ,255), Thickness = 1, Transparency = 1, Visible = false});

        RunService.Heartbeat:Connect(function()

            Circle.Visible = SilentAim.Enabled and SilentAim.Fov.Visible;
            if Circle.Visible then
                Circle.Position = Vector2.new(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y);
                Circle.Radius = SilentAim.Fov.Radius;
            end;
            
        end);

    end;

end;


