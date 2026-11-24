# 发布 tap 仓库后放在 zahT3/homebrew-tap 的 Formula/ 下即可：
#   brew install zahT3/tap/ip-please
#
# sha256 需要用发布产物的校验值替换：
#   curl -sL https://github.com/zahT3/ip-please/archive/refs/tags/v0.5.2.tar.gz | shasum -a 256
class IpPlease < Formula
  desc "Egress-identity auditor and fail-closed circuit breaker for AI accounts (macOS)"
  homepage "https://github.com/zahT3/ip-please"
  url "https://github.com/zahT3/ip-please/archive/refs/tags/v0.5.2.tar.gz"
  sha256 "2a5f23d19acfd3e6aa4aabba87a31ab8dbb38d134fa87600ecac89e796cbb9f0"
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

        sudo #{libexec}/install.sh

      卸载系统侧组件：

        sudo #{libexec}/uninstall.sh
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/ipp version")
  end
end
