{ pkgs, ... }: {
  # 选择 Nix 软件源频道
  channel = "stable-23.11"; 

  # 安装必要的软件包
  packages = [
    pkgs.nodePackages.firebase-tools
    pkgs.jdk17
    pkgs.unzip
  ];

  # 设置环境变量
  env = {};

  idx = {
    # 自动安装 VS Code 插件
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];

    # 关键：定义预览窗口的行为
    previews = {
      enable = true;
      previews = {
        web = {
          # 告诉 IDX 怎么启动你的 Web App
          command = ["flutter" "run" "--machine" "-d" "web-server" "--web-hostname" "0.0.0.0" "--web-port" "$PORT"];
          manager = "web";
        };
      };
    };
  };
}