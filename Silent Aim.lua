repeat task.wait(); until game:IsLoaded();
repeat task.wait(); until game:GetService("Players").LocalPlayer.PlayerGui.Menu.Main.Main.Options.Inventory.List.Primary.Title.Text ~= "Loading..";

-- // Variables
local Players = game:GetService("Players");
local LocalPlayer = Players.LocalPlayer;
local CurrentCamera = game:GetService("Workspace").CurrentCamera;
local UserInputService = game:GetService("UserInputService");
local Environment = getexecutorname and getexecutorname();
local RunService = game:GetService("RunService");
local Gravity = Vector3.new(0, -192, 0); -- For The Bullets!
local Drawings = { };


-- // Modules
if Environment and string.match(string.lower(Environment), "xeno") then
    return LocalPlayer:Kick("Xeno Is Not Supported, Executor Must Have Drawing and hookfunction And require Or getgc."); -- No Idea If This Shitty External Sill Lives.
end;

local Success, BulletHandler = pcall(require, game:GetService("ReplicatedStorage").Modules.Client.Handlers.BulletHandler);  
if (not Success and not getgc) or not hookfunction or not Drawing then
    return LocalPlayer:Kick("Executor Is Not Supported, Executor Must Have Drawing and hookfunction And require Or getgc.");

elseif getgc then -- Some Executors Have getgc But Cant require ?
    for _,v in getgc() do
        if typeof(v) == "function" and debug.info(v, "n") == "" and debug.info(v, "l") == 92 then -- Not Using getinfo As If They Dont Have Working require, Then Dev Is Proably Lazy And Hasnt Made Full Debug Lib.
            BulletHandler = v;
            break;
        end;
    end;
    
    if not BulletHandler then
        return LocalPlayer:Kick("Executor Is Not Supported, Executor Must Have Drawing and hookfunction And require Or getgc.");
    end;

end;

-- // Tables
Keybind = "RightShift"; -- For UI
local SilentAim = {   
    Enabled = false,
    HitPart = "Head",
    Prediction = true, -- If You Ever Don't Want It For Some Reason.
    PenCheck = false,
    
    Fov = { 
        Visible = false,
        Radius = 600
    }
};

-- // Functions
local Functions = { };
do
    
    function Functions:IsAlive(Player)
        if Player and Player.Character and Player.Character:GetAttribute("Health") > 0 and Player.Character:GetAttribute("State") == "Alive" then
            return true;
        end;
        return false;
    end;
    
    function Functions:GetTarget()
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
            
            if not OnScreen then
                continue;
            end;
            
            if Distance < Closest then
                Closest = Distance;
                HitBox = HitPart;
            end;
            
        end;
        
        return HitBox;
    end;

    function Functions:CalCulateBulletDrop(To, From, MuzzleVelovity) -- All Calulations Are 100% Correct I Belive I Havent Seen A Single Issue.
        local Distance = (To - From).Magnitude;
        local Time = Distance / MuzzleVelovity;
        local Vertical = 0.5 * Gravity * Time^2; 
        
        return Vertical;
    end;

    function Functions:Predict(Target, From, MuzzleVelovity)
        local Distance = (Target.Position - From).Magnitude;
        local Time = Distance / MuzzleVelovity;

        return Target.Position + (Target.Velocity * Time);
    end;

    function Functions:GetWalls(Origin, Target, ...)
        local Ignore = {CurrentCamera, ...};
        local Walls = { };

        local Direction = Target.Position - Origin;
        local NoMoreWalls = false;
        
        local function AddWall()
            local Hit = workspace:FindPartOnRayWithIgnoreList(Ray.new(Origin, Direction), Ignore, false, true);
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

        if not Is_Local_Platers_Bullet then
            return Old(Origin, LookVector, p33, Weapon_Data, Ignore, Is_Local_Platers_Bullet, Tick);
        end;

        if not SilentAim.Enabled then 
            return Old(Origin, LookVector, p33, Weapon_Data, Ignore, Is_Local_Platers_Bullet, Tick);
        end;

        local Target = Functions:GetTarget();
        if not Target then
            return Old(Origin, LookVector, p33, Weapon_Data, Ignore, Is_Local_Platers_Bullet, Tick);
        end;

        if SilentAim.PenCheck and not Functions:PenCheck(Origin, Target, Weapon_Data.Source.Penetration, table.unpack(Ignore)) then 
            return Old(Origin, LookVector, p33, Weapon_Data, Ignore, Is_Local_Platers_Bullet, Tick);
        end

        local TargtePosition = SilentAim.Prediction and Functions:Predict(Target, Origin, Weapon_Data.Source.MuzzleVelocity) or not SilentAim.Prediction and Target.Position;
        local VerticalDrop = Functions:CalCulateBulletDrop(Origin, TargtePosition, Weapon_Data.Source.MuzzleVelocity);
        
        LookVector = (TargtePosition - VerticalDrop - Origin).Unit;

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
            end
            if Functions:IsMouseOver(Enable) then
                if SilentAim.Enabled then
                    SilentAim.Enabled = false;
                    Enable.Color = Color3.fromRGB(52, 52, 52);
                else
                    SilentAim.Enabled = true;
                    Enable.Color = Color3.fromRGB(2, 54, 8);
                end;
            elseif Functions:IsMouseOver(PenCheck) then
                if SilentAim.PenCheck then
                    SilentAim.PenCheck = false;
                    PenCheck.Color = Color3.fromRGB(52, 52, 52);
                else
                    SilentAim.PenCheck = true;
                    PenCheck.Color = Color3.fromRGB(2, 54, 8);
                end;
            elseif Functions:IsMouseOver(ShowFov) then
                if SilentAim.Fov.Visible then
                    SilentAim.Fov.Visible = false;
                    ShowFov.Color = Color3.fromRGB(52, 52, 52);
                else
                    SilentAim.Fov.Visible = true;
                    ShowFov.Color = Color3.fromRGB(2, 54, 8);
                end;
            elseif Functions:IsMouseOver(HitScan) then
                if HitScanText.Text == "HEAD, torso" then
                    SilentAim.HitPart = "Torso"
                    HitScanText.Text = "head, TORSO";
                else
                    SilentAim.HitPart = "Head"
                    HitScanText.Text = "HEAD, torso";
                end;
            elseif Functions:IsMouseOver(Prediction) then
                if SilentAim.Prediction then
                    SilentAim.Prediction = false;
                    Prediction.Color = Color3.fromRGB(52, 52, 52);
                else
                    SilentAim.Prediction = true;
                    Prediction.Color = Color3.fromRGB(2, 54, 8);
                end;
            end;
        elseif Input.KeyCode == (Enum.KeyCode[Keybind] or Enum.KeyCode.RightShift) then
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
            for i = 1, #Drawings do -- Make Sure We Move Everything
                Drawings[i].Position = Drawings[i].Position - Distance;
                StartPos = UserInputService:GetMouseLocation();
            end;
        elseif SliderDrag and Background.Visible and Functions:IsMouseOver(FovRadiusBackround) then
            local Ammount = (UserInputService:GetMouseLocation().X - FovRadiusBackround.Position.X) / FovRadiusBackround.Size.X; 
            FovRadius.Size = Vector2.new(FovRadiusBackround.Size.X * Ammount, FovRadius.Size.Y);
            FovRadiusNumber.Text = tostring(math.floor(600 * Ammount));
            SilentAim.Fov.Radius = tonumber(FovRadiusNumber.Text);
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
