# 发布 tap 仓库后放在 zahT3/homebrew-tap 的 Formula/ 下即可：
#   brew install zahT3/tap/ip-please
#
# sha256 需要用发布产物的校验值替换：
#   curl -sL https://github.com/zahT3/ip-please/archive/refs/tags/v0.6.4.tar.gz | shasum -a 256
class IpPlease < Formula
  desc "Egress-identity auditor and fail-closed circuit breaker for AI accounts (macOS)"
  homepage "https://github.com/zahT3/ip-please"
  url "https://github.com/zahT3/ip-please/archive/refs/tags/v0.6.4.tar.gz"
  sha256 "0f45a74b15556e7e66c0ccdfb8bb4549f8be5c3628f5941f1cc5b5c17b8e0b7a"
  license "MIT"

  depends_on :macos

  def install
    libexec.install Dir["*"]
    %w[ipp ipplz ip-please].each do |cmd|
      (bin/cmd).write <<~EOS
        #!/bin/bash
        exec "#{libexec}/bin/ip-please" "$@"
      EOS
    end
  end

  def caveats
    <<~EOS
      ip-please 还需要安装系统侧的熔断器与浏览器策略（会写 /etc、加载 launchd，需要 sudo）：

        #{libexec}/install.sh

      卸载系统侧组件：

        sudo #{libexec}/uninstall.sh
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ipp version")
  end
end
