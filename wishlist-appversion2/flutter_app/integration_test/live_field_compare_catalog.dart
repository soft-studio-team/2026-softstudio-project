class LiveCompareProduct {
  const LiveCompareProduct(this.url, {this.live});

  final String url;
  final LiveCompareExpected? live;
}

class LiveCompareExpected {
  const LiveCompareExpected({
    required this.name,
    required this.price,
    required this.image,
    this.brand,
  });

  final String name;
  final int price;
  final String image;
  final String? brand;
}

class LiveCompareMall {
  const LiveCompareMall(this.mall, this.products);

  final String mall;
  final List<LiveCompareProduct> products;
}

/// 자동 채움 PASS 50몰. 실제 페이지에서 확인한 판매가(첫구매·카드 쿠폰 제외).
/// 엔진 상품명에는 브랜드가 붙을 수 있으므로 live.name 은 화면에 보이는 상품명이다.
const liveCompareMalls = <LiveCompareMall>[
  LiveCompareMall('11번가', [
    LiveCompareProduct('https://www.11st.co.kr/products/5932454122'),
  ]),
  LiveCompareMall('무신사', [
    LiveCompareProduct(
      'https://www.musinsa.com/products/6558705',
      live: LiveCompareExpected(
        name: '26 SS 세미 크롭 라이트웨이트 스트라이프 [반팔] 셔츠 (3컬러)',
        price: 35900,
        image:
            'https://image.msscdn.net/images/goods_img/20260527/6558705/6558705_17821067310601_500.jpg',
        brand: '효지',
      ),
    ),
    LiveCompareProduct(
      'https://www.musinsa.com/products/3348384',
      live: LiveCompareExpected(
        name: '와이드 투 턱 워시드 데님 버뮤다 팬츠 블루',
        price: 78000,
        image:
            'https://image.msscdn.net/images/goods_img/20230607/3348384/3348384_16861027432924_500.jpg',
        brand: '케이엔드',
      ),
    ),
    LiveCompareProduct(
      'https://www.musinsa.com/products/6152461',
      live: LiveCompareExpected(
        name: '컴포트 썸머 와이드 팬츠 브라운',
        price: 30400,
        image:
            'https://image.msscdn.net/images/goods_img/20260318/6152461/6152461_17841009414778_500.jpg',
        brand: '모즈모즈',
      ),
    ),
  ]),
  LiveCompareMall('W컨셉', [
    LiveCompareProduct(
      'https://www.wconcept.co.kr/Product/307615241',
      live: LiveCompareExpected(
        name: '벨리브 골지 폴라 긴팔 니트',
        price: 19900,
        image:
            'https://product-image.wconcept.co.kr/productimg/image/img2/41/307615241_GG10272.jpg',
        brand: '트위',
      ),
    ),
    LiveCompareProduct('https://www.wconcept.co.kr/Product/305573391'),
    LiveCompareProduct('https://www.wconcept.co.kr/Product/305914779'),
  ]),
  LiveCompareMall('29CM', [
    LiveCompareProduct(
      'https://www.29cm.co.kr/products/4058252',
      live: LiveCompareExpected(
        name: '샥스 Z 칼리스트라 W - [블랙 / IR5510-001]',
        price: 159000,
        image:
            'https://img.29cm.co.kr/item/202606/11f16f98cff926419090358d89120339.png',
        brand: '나이키',
      ),
    ),
    LiveCompareProduct(
      'https://www.29cm.co.kr/products/1577769',
      live: LiveCompareExpected(
        name: '퀸 비키니 브라_화이트',
        price: 109000,
        image:
            'https://img.29cm.co.kr/next-product/2022/05/26/386c619c0ffe475bb36a99a77957ef2b_20220526172232.jpg',
        brand: '아그넬',
      ),
    ),
    LiveCompareProduct(
      'https://www.29cm.co.kr/products/3503849',
      live: LiveCompareExpected(
        name: '(사이즈추가)High-neck Leather Blouson Jacket VL5AJ093_2color',
        price: 206400,
        image:
            'https://img.29cm.co.kr/next-product/2025/09/11/e63e8980e9434ada929917121dcc59b0_20250911123238.jpg',
        brand: '레이브',
      ),
    ),
  ]),
  LiveCompareMall('FILA', [
    LiveCompareProduct('https://www.fila.co.kr/products/1100fs262rs11m001490'),
  ]),
  LiveCompareMall('하고', [
    LiveCompareProduct('https://www.hago.kr/goods/detail/750307'),
  ]),
  LiveCompareMall('룩핀', [
    LiveCompareProduct('https://www.lookpin.co.kr/products/3083865'),
    LiveCompareProduct('https://www.lookpin.co.kr/products/2724519'),
  ]),
  LiveCompareMall('탑텐', [
    LiveCompareProduct(
      'https://topten10.goodwearmall.com/product/MSG2UL2205NVP/detail',
    ),
  ]),
  LiveCompareMall('무인양품', [
    LiveCompareProduct('https://mujikorea.co.kr/products/view/1005531'),
    LiveCompareProduct('https://mujikorea.co.kr/products/view/1005528'),
  ]),
  LiveCompareMall('현대Hmall', [
    LiveCompareProduct(
      'https://www.hmall.com/md/pda/itemPtc?slitmCd=2060464676',
    ),
  ]),
  LiveCompareMall('롯데온', [
    LiveCompareProduct('https://www.lotteon.com/p/product/LO2724337622'),
  ]),
  LiveCompareMall('미쏘', [
    LiveCompareProduct(
      'https://mixxo.com/product/detail.html?product_no=12455',
      live: LiveCompareExpected(
        name: '[에센셜] 루즈핏 긴팔 니트_MIWKAG530T',
        price: 49900,
        image:
            'https://cafe24img.poxo.com/mixxo/web/product/big/202604/af4c717f08d808fbe021d901ac0b8fe2.jpg',
        brand: '미쏘',
      ),
    ),
    LiveCompareProduct(
      'https://mixxo.com/product/detail.html?product_no=9813',
      live: LiveCompareExpected(
        name: '스퀘어넥 퍼프 블라우스_MIWBWF504G',
        price: 39900,
        image:
            'https://cafe24img.poxo.com/mixxo/web/product/big/202508/f0a701a6e813203b651c6ae91d3ce324.jpg',
        brand: '미쏘',
      ),
    ),
    LiveCompareProduct(
      'https://mixxo.com/product/detail.html?product_no=12454',
      live: LiveCompareExpected(
        name: '숏트렌치_MIWJTG40SS',
        price: 99900,
        image:
            'https://cafe24img.poxo.com/mixxo/web/product/big/202604/56f9d9ab63fade7be842a099ff72eb4e.jpg',
        brand: '미쏘',
      ),
    ),
  ]),
  LiveCompareMall('데일리쥬', [
    LiveCompareProduct(
      'https://dailyjou.com/product/detail.html?product_no=22794',
      live: LiveCompareExpected(
        name: '리즌 레이어드 라운드넥 반팔 니트',
        price: 36000,
        image:
            'https://cafe24.poxo.com/ec01/cocomimi93/Kcc0fQ0DsTHpcxHYW7fqLaBIC/o2a/jM6bRPEprGgUE2Ahi38o9n6QY5e//FBcVGbltRbal2kV5zxlu1744asA==/_/web/product/big/202603/4c9aa6ce70db04379a07e87a9472452a.webp',
      ),
    ),
    LiveCompareProduct(
      'https://dailyjou.com/product/detail.html?product_no=23688',
      live: LiveCompareExpected(
        name: '일리아 5부 프릴 카프리 팬츠',
        price: 46000,
        image:
            'https://cafe24.poxo.com/ec01/cocomimi93/Kcc0fQ0DsTHpcxHYW7fqLaBIC/o2a/jM6bRPEprGgUE2Ahi38o9n6QY5e//FBcVGbltRbal2kV5zxlu1744asA==/_/web/product/big/202603/ed3a53c275929515dbe0de01e4402ecd.webp',
      ),
    ),
    LiveCompareProduct(
      'https://dailyjou.com/product/detail.html?product_no=23726',
      live: LiveCompareExpected(
        name: '헤리드 시스루 레이스 긴소매 티셔츠',
        price: 20000,
        image:
            'https://cafe24.poxo.com/ec01/cocomimi93/Kcc0fQ0DsTHpcxHYW7fqLaBIC/o2a/jM6bRPEprGgUE2Ahi38o9n6QY5e//FBcVGbltRbal2kV5zxlu1744asA==/_/web/product/big/202604/7c5913f3b045618b0ea3f732b3b65204.webp',
      ),
    ),
  ]),
  LiveCompareMall('리', [
    LiveCompareProduct(
      'https://leekorea.co.kr/product/detail.html?product_no=14252',
      live: LiveCompareExpected(
        name: '로코 포켓 데님 셔츠 인디고 라이트',
        price: 99000,
        image:
            'https://leekorea.co.kr/web/product/big/202606/ec8667b06f230191e25a44ab54c94c04.jpg',
      ),
    ),
  ]),
  LiveCompareMall('필루미네이트', [
    LiveCompareProduct(
      'https://filluminate.com/product/detail.html?product_no=11735',
      live: LiveCompareExpected(
        name: 'FLM 스몰 로고 피그먼트 티셔츠-브라운',
        price: 45000,
        image:
            'https://filluminate.com/web/product/big/202605/021f3e05962325f308a8e83ebc946676.jpg',
      ),
    ),
    LiveCompareProduct(
      'https://filluminate.com/product/detail.html?product_no=11734',
      live: LiveCompareExpected(
        name: '나일론 투 턱 테크 팬츠-5Color',
        price: 49000,
        image:
            'https://filluminate.com/web/product/big/202605/23d6cd3a632f239f5eb0ae3ffd12a969.jpg',
      ),
    ),
    LiveCompareProduct(
      'https://filluminate.com/product/detail.html?product_no=11736',
      live: LiveCompareExpected(
        name: 'FLM 스몰 로고 피그먼트 티셔츠-차콜',
        price: 45000,
        image:
            'https://filluminate.com/web/product/big/202605/3f5b1e325de69cfc0a482c430366916d.jpg',
      ),
    ),
  ]),
  LiveCompareMall('어반스터프', [
    LiveCompareProduct(
      'https://urbanstoff.com/product/detail.html?product_no=507',
      live: LiveCompareExpected(
        name: '로우 썬 아트워크 버뮤다 스웨트 팬츠 (멜란지)',
        price: 69000,
        image:
            'https://ecimg.cafe24img.com/pg1589b23882635070/urbanstoff001/web/product/big/20260427/3ccc7f264e8bd398c7633b7f4eaf94c7.jpg',
        brand: '어반스터프',
      ),
    ),
    LiveCompareProduct(
      'https://urbanstoff.com/product/detail.html?product_no=506',
      live: LiveCompareExpected(
        name: '버티컬 데님 버뮤다 팬츠 (다크 네이비)',
        price: 82000,
        image:
            'https://ecimg.cafe24img.com/pg1589b23882635070/urbanstoff001/web/product/big/20260427/4336fbdace68a0b178e9ccc07dec3e0c.jpg',
        brand: '어반스터프',
      ),
    ),
    LiveCompareProduct(
      'https://urbanstoff.com/product/detail.html?product_no=505',
      live: LiveCompareExpected(
        name: '백 포켓 아트워크 버뮤다 팬츠 (인디고)',
        price: 79000,
        image:
            'https://ecimg.cafe24img.com/pg1589b23882635070/urbanstoff001/web/product/big/20260427/08284f2f3ed28a922eeb4a73c8831609.jpg',
        brand: '어반스터프',
      ),
    ),
  ]),
  LiveCompareMall('낫포유', [
    LiveCompareProduct(
      'https://not4u.kr/product/detail.html?product_no=261',
      live: LiveCompareExpected(
        name: '소프트 바디 미스트 115ml',
        price: 15900,
        image:
            'https://not4u.kr/web/product/big/202402/a68857d33d5c671568a528494b17b42c.jpg',
      ),
    ),
    LiveCompareProduct(
      'https://not4u.kr/product/detail.html?product_no=262',
      live: LiveCompareExpected(
        name: '샤워 호스 1.7m',
        price: 12000,
        image:
            'https://not4u.kr/web/product/big/202402/a2d643a170ffa65d4cc77a17224d3416.jpg',
      ),
    ),
  ]),
  LiveCompareMall('인사일런스', [
    LiveCompareProduct(
      'https://insilence.co.kr/product/detail.html?product_no=7481',
      live: LiveCompareExpected(
        name: '스탠실 그래픽 티셔츠 CHARCOAL',
        price: 59000,
        image:
            'https://insilence.co.kr/web/product/big/202604/2e364b4c8c01e02e418313635db74694.jpg',
      ),
    ),
    LiveCompareProduct(
      'https://insilence.co.kr/product/detail.html?product_no=7303',
      live: LiveCompareExpected(
        name: '개리슨 벨트 BLACK',
        price: 49000,
        image:
            'https://insilence.co.kr/web/product/big/202602/153251e5f2e00b8728d1781124ccb650.jpg',
      ),
    ),
    LiveCompareProduct(
      'https://insilence.co.kr/product/detail.html?product_no=7483',
      live: LiveCompareExpected(
        name: '스탠실 그래픽 티셔츠 WHITE',
        price: 59000,
        image:
            'https://insilence.co.kr/web/product/big/202604/44862852e0fb5f9d0abbfad9cdb324da.jpg',
      ),
    ),
  ]),
  LiveCompareMall('파브레가', [
    LiveCompareProduct(
      'https://fabregat.kr/product/detail.html?product_no=1038',
      live: LiveCompareExpected(
        name: 'Brom Carabiner Leather Keyring (Black)',
        price: 44000,
        image:
            'https://fabregat.kr/web/product/big/202605/872e33be2937be1918aa6ba242351d78.jpg',
        brand: '파브레가',
      ),
    ),
  ]),
  LiveCompareMall('핫핑', [
    LiveCompareProduct(
      'https://hotping.co.kr/product/detail.html?product_no=29570',
      live: LiveCompareExpected(
        name: '나의베스트 밴딩와이드팬츠',
        price: 24800,
        image:
            'https://hotping.co.kr/web/product/big/202405/43f2cf982d53323afb04e75ab28e62c9.jpg',
      ),
    ),
    LiveCompareProduct(
      'https://hotping.co.kr/product/detail.html?product_no=36728',
      live: LiveCompareExpected(
        name: '클로이 단가라 골지니트 나시',
        price: 14800,
        image:
            'https://hotping.co.kr/web/product/big/202507/e8efd2f4c8fbd18ffd374d0016bf6cd2.jpg',
      ),
    ),
    LiveCompareProduct(
      'https://hotping.co.kr/product/detail.html?product_no=37586',
      live: LiveCompareExpected(
        name: '하나쯤필수 크롭 브라탑나시',
        price: 19800,
        image:
            'https://hotping.co.kr/web/product/big/202505/44473a3294cfa586e26f16a9ddcb1bbc.jpg',
      ),
    ),
  ]),
  LiveCompareMall('유니클로', [
    LiveCompareProduct(
      'https://www.uniqlo.com/kr/ko/products/E486612-000/00?colorDisplayCode=65&sizeDisplayCode=005',
    ),
  ]),
  LiveCompareMall('SSG', [
    LiveCompareProduct(
      'https://www.ssg.com/item/itemView.ssg?itemId=1000571660298',
    ),
    LiveCompareProduct(
      'https://www.ssg.com/item/itemView.ssg?itemId=1000277700787',
    ),
  ]),
  LiveCompareMall('더현대Hi', [
    LiveCompareProduct(
      'https://hi.thehyundai.com/product/40B1406274?sectId=1031',
    ),
  ]),
  LiveCompareMall('에이블리', [
    LiveCompareProduct('https://mobile.a-bly.com/goods/74156532'),
  ]),
  LiveCompareMall('지그재그', [
    LiveCompareProduct('https://zigzag.kr/catalog/products/144255443'),
  ]),
  LiveCompareMall('KREAM', [
    LiveCompareProduct('https://kream.co.kr/products/1012767'),
    LiveCompareProduct('https://kream.co.kr/products/748804'),
  ]),
  LiveCompareMall('게스', [
    LiveCompareProduct(
      'https://www.guesskorea.com/product/detail.html?product_no=45471',
      live: LiveCompareExpected(
        name: '남성 데님 프린트 삼각 반팔 티셔츠_LIGHT GREY',
        price: 39000,
        image:
            'https://www.guesskorea.com/web/product/big/202603/cea6a7276868637421b68e8fb91a7274.jpg',
        brand: '게스',
      ),
    ),
    LiveCompareProduct(
      'https://www.guesskorea.com/product/detail.html?product_no=45470',
      live: LiveCompareExpected(
        name: '남녀공용 GUESS 미니 로고 반팔티셔츠_BLUE',
        price: 29000,
        image:
            'https://www.guesskorea.com/web/product/big/202601/7d727b195895b3c75888c0e97f668294.png',
        brand: '게스',
      ),
    ),
    LiveCompareProduct(
      'https://www.guesskorea.com/product/detail.html?product_no=45472',
      live: LiveCompareExpected(
        name: '남녀공용 해변 프린트 반팔 티셔츠_LIGHT YELLOW',
        price: 29000,
        image:
            'https://www.guesskorea.com/web/product/big/202603/439646938f8f472889c00581fb264ac9.jpg',
        brand: '게스',
      ),
    ),
  ]),
  LiveCompareMall('반스', [
    LiveCompareProduct(
      'https://www.vans.co.kr/PRODUCT/VN000D6WBOM',
      live: LiveCompareExpected(
        name: '올드스쿨',
        price: 57000,
        image: 'https://img.vans.com/image/upload/VN000D6WBOM-HERO.jpg',
        brand: 'VANS',
      ),
    ),
    LiveCompareProduct(
      'https://www.vans.co.kr/PRODUCT/VN000D9NBLK',
      live: LiveCompareExpected(
        name: '반스 프리미엄 어센틱 44 컴뱃',
        price: 135000,
        image: 'https://img.vans.com/image/upload/VN000D9NBLK-HERO.jpg',
        brand: 'VANS',
      ),
    ),
    LiveCompareProduct(
      'https://www.vans.co.kr/PRODUCT/VN000VB2HO8',
      live: LiveCompareExpected(
        name: '토들러 올드스쿨 벨크로 레오파드',
        price: 55000,
        image:
            'https://image.vans.co.kr/cmsstatic/product/43320/VN000VB2HO8-HERO.jpg',
        brand: 'VANS',
      ),
    ),
  ]),
  LiveCompareMall('커버낫', [
    LiveCompareProduct(
      'https://covernat.co.kr/product/detail.html?product_no=5996',
      live: LiveCompareExpected(
        name: '케이블 라운드 하프 니트 네이비',
        price: 39000,
        image: 'https://covernat.co.kr/web/product/big/CO2302KT23NA_1.jpg',
        brand: '커버낫',
      ),
    ),
    LiveCompareProduct(
      'https://covernat.co.kr/product/detail.html?product_no=18025',
      live: LiveCompareExpected(
        name: '우먼 레이어드 슬리브리스 원피스 블랙',
        price: 125100,
        image:
            'https://covernat.co.kr/web/product/big/202605/9ef7df29644ea4f1a9a5a693142b66fa.jpg',
        brand: '커버낫',
      ),
    ),
    LiveCompareProduct(
      'https://covernat.co.kr/product/detail.html?product_no=8581',
      live: LiveCompareExpected(
        name: '서퍼샵 티셔츠 화이트',
        price: 19000,
        image:
            'https://covernat.co.kr/web/product/big/202409/07b0db05c4d274549d1bd9161a8dbba2.jpg',
        brand: '커버낫',
      ),
    ),
  ]),
  LiveCompareMall('코드그라피', [
    LiveCompareProduct(
      'https://code-graphy.com/product/detail.html?product_no=6388',
      live: LiveCompareExpected(
        name: '버뮤다 카펜터 코튼 팬츠_베이지',
        price: 70300,
        image:
            'https://cafe24.poxo.com/ec01/cgraphy/nDa3+VeoMR5vyddRVokF8ltOczmmZefMqiQFCv903NO3uqDUY03GsJUYRdWtWSXw916shfsw86QFrSvagfRRrA==/_/web/product/big/202504/e3986480c1dc868d19a4a44b2c3861cb.jpg',
      ),
    ),
  ]),
  LiveCompareMall('후아유', [
    LiveCompareProduct(
      'https://whoau.com/product/detail.html?product_no=4852',
      live: LiveCompareExpected(
        name: 'USA Printing T-shirt',
        price: 19900,
        image:
            'https://cafe24.poxo.com/ec01/whoaukr/3JPAsJn/jGkesyYvH/tEacJ//FpiOmI0G0IBVoMAo1XCOUL3mT6Caj09FWLKVeGQ1kJx/IhRfpWw9NNnns5vjA==/_/web/product/big/202605/1abcbd56ea4c53df7a822552aaac74f5.jpg',
      ),
    ),
    LiveCompareProduct(
      'https://whoau.com/product/detail.html?product_no=4847',
      live: LiveCompareExpected(
        name: 'Steve Collar T-Shirt',
        price: 27900,
        image:
            'https://cafe24.poxo.com/ec01/whoaukr/3JPAsJn/jGkesyYvH/tEacJ//FpiOmI0G0IBVoMAo1XCOUL3mT6Caj09FWLKVeGQ1kJx/IhRfpWw9NNnns5vjA==/_/web/product/big/202605/b7a4990afb8b49eb0649eee27a9315ea.jpg',
      ),
    ),
    LiveCompareProduct(
      'https://whoau.com/product/detail.html?product_no=4853',
      live: LiveCompareExpected(
        name: 'USA Logo T-shirt',
        price: 19900,
        image:
            'https://cafe24.poxo.com/ec01/whoaukr/3JPAsJn/jGkesyYvH/tEacJ//FpiOmI0G0IBVoMAo1XCOUL3mT6Caj09FWLKVeGQ1kJx/IhRfpWw9NNnns5vjA==/_/web/product/big/202603/06394434e4fa194796b9a1a320c653f9.jpg',
      ),
    ),
  ]),
  LiveCompareMall('Aritzia', [
    LiveCompareProduct(
      'https://www.aritzia.com/intl/en/product/airbutter%E2%84%A2-repose-longsleeve/133550.html?color=35023',
    ),
    LiveCompareProduct(
      'https://www.aritzia.com/intl/en/product/technique-dress/124784.html',
    ),
  ]),
  LiveCompareMall('노이아고', [
    LiveCompareProduct(
      'https://noirer.com/product/detail.html?product_no=2141',
      live: LiveCompareExpected(
        name: '멀티 웨일 코듀로이 블루종 (딥브라운)',
        price: 219000,
        image:
            'https://noirer.com/web/product/big/202509/898f768eacf0492bc86b7c3d15e95b6d.jpg',
        brand: 'NOIRER',
      ),
    ),
    LiveCompareProduct(
      'https://noirer.com/product/detail.html?product_no=2140',
      live: LiveCompareExpected(
        name: '헤어리 투 톤 퍼 자켓 (베이지)',
        price: 245000,
        image:
            'https://noirer.com/web/product/big/202509/dd2bc1cae8e76b778c41c5fde0ee2370.jpg',
        brand: 'NOIRER',
      ),
    ),
    LiveCompareProduct(
      'https://noirer.com/product/detail.html?product_no=2142',
      live: LiveCompareExpected(
        name: '캐시미어 더블 브레스티드 맥시 코트 (블랙)',
        price: 425000,
        image:
            'https://noirer.com/web/product/big/202509/7caed779efc9de3bd9fc82187fe4fee0.jpg',
        brand: 'NOIRER',
      ),
    ),
  ]),
  LiveCompareMall('립합', [
    LiveCompareProduct(
      'https://liphop.com/product/detail.html?product_no=17849',
      live: LiveCompareExpected(
        name: 'BLACK WEDGE SLIPPERS',
        price: 290000,
        image:
            'https://liphop.com/web/product/big/202406/ed7b52e91003133082ed4b85ab5e54e4.jpg',
      ),
    ),
  ]),
  LiveCompareMall('마하그리드', [
    LiveCompareProduct(
      'https://mahagrid.com/product/detail.html?product_no=3854',
      live: LiveCompareExpected(
        name: 'THIRD LOGO BACKPACK[BLACK]',
        price: 109000,
        image:
            'https://mahagrid.com/web/product/big/202602/c9908ec067fc6dd75124f9ed69c164a7.jpg',
      ),
    ),
  ]),
  LiveCompareMall('비바스튜디오', [
    LiveCompareProduct(
      'https://vivastudio.co.kr/product/detail.html?product_no=5485',
    ),
  ]),
  LiveCompareMall('아모멘토', [
    LiveCompareProduct(
      'https://amomento.co/product/button-neck-knit-2colors/1642/',
      live: LiveCompareExpected(
        name: 'BUTTON NECK KNIT (2COLORS)',
        price: 249000,
        image:
            'https://cafe24.poxo.com/ec01/amomentoweb/S6XixLXKQIBS6XUNf2tKGojORIH3PPuABxGbuJPvDdnCZ/1q6lF/ulSM9K1X+EnNoFwo9ozOPtj4s2Rf+txSew==/_/web/product/big/202501/1652618da0b72a1a986b47a538eb7666.jpg',
      ),
    ),
    LiveCompareProduct(
      'https://amomento.co/product/detail.html?product_no=1643',
      live: LiveCompareExpected(
        name: 'CLASSIC LOAFER',
        price: 479000,
        image:
            'https://cafe24.poxo.com/ec01/amomentoweb/S6XixLXKQIBS6XUNf2tKGojORIH3PPuABxGbuJPvDdnCZ/1q6lF/ulSM9K1X+EnNoFwo9ozOPtj4s2Rf+txSew==/_/web/product/big/202408/b8e5f6e4da18556b7e158ebb8910f65a.jpg',
      ),
    ),
  ]),
  LiveCompareMall('앤더슨벨', [
    LiveCompareProduct(
      'https://www.anderssonbell.com/product/detail.html?product_no=10605',
      live: LiveCompareExpected(
        name: 'UNISEX LOVE T-SHIRT atb1252u(RED)',
        price: 95000,
        image:
            'https://www.anderssonbell.com/web/product/big/202602/1fbc361c12d31cf13b0a3e5b7c1cfb23.jpg',
        brand: '앤더슨벨',
      ),
    ),
  ]),
  LiveCompareMall('예일', [
    LiveCompareProduct(
      'https://yaleapparel.co.kr/product/detail.html?product_no=18179',
      live: LiveCompareExpected(
        name: '스몰 아치 스트라이프 후드 집업_라이트 그레이',
        price: 79900,
        image:
            'https://yaleapparel.co.kr/web/product/big/202602/4bd91aef3f8b85c0a2d36f5da861e85e.jpg',
        brand: 'Yale',
      ),
    ),
    LiveCompareProduct(
      'https://yaleapparel.co.kr/product/detail.html?product_no=18180',
      live: LiveCompareExpected(
        name: '스몰 아치 스트라이프 후드 집업_그레이',
        price: 79900,
        image:
            'https://yaleapparel.co.kr/web/product/big/202602/f4cc7fb241213f262c09f9f8047866cf.jpg',
        brand: 'Yale',
      ),
    ),
    LiveCompareProduct(
      'https://yaleapparel.co.kr/product/detail.html?product_no=18178',
      live: LiveCompareExpected(
        name: '불독스 후드_네이비',
        price: 69900,
        image:
            'https://yaleapparel.co.kr/web/product/big/202602/604898fe05f58561a8491aebe1bef9ed.jpg',
        brand: 'Yale',
      ),
    ),
  ]),
  LiveCompareMall('위드윤', [
    LiveCompareProduct(
      'https://withyoon.com/product/detail.html?product_no=19342',
      live: LiveCompareExpected(
        name: '모노 린넨 가디건',
        price: 68000,
        image:
            'https://cafe24img.poxo.com/choiwjddbs/web/product/big/202607/4deb71bbfca1720eb1c187d72f550144.webp',
      ),
    ),
    LiveCompareProduct(
      'https://withyoon.com/product/detail.html?product_no=19341',
      live: LiveCompareExpected(
        name: '리브 셔링 블라우스',
        price: 49800,
        image:
            'https://cafe24img.poxo.com/choiwjddbs/web/product/big/202607/ac04d377e65f83e32f0b40b8779ff67e.webp',
      ),
    ),
    LiveCompareProduct(
      'https://withyoon.com/product/detail.html?product_no=19343',
      live: LiveCompareExpected(
        name: '브루노 린넨 슬리브리스 블라우스',
        price: 38900,
        image:
            'https://cafe24img.poxo.com/choiwjddbs/web/product/big/202607/08a677682df74d6ce2efb8ad0ab03f69.webp',
      ),
    ),
  ]),
  LiveCompareMall('패션플러스', [
    LiveCompareProduct(
      'https://www.fashionplus.co.kr/goods/detail/418168398',
    ),
  ]),
  LiveCompareMall('프롬비기닝', [
    LiveCompareProduct(
      'https://frombeginning.co.kr/product/detail.html?product_no=22025',
      live: LiveCompareExpected(
        name: '앤디 스트링 이지 밴딩 팬츠',
        price: 61000,
        image:
            'https://ecimg.cafe24img.com/pg1985b57457872046/frombegining/web/product/big/20260807/fb65743388ee09aabee7aea26b0ea272.gif',
        brand: '프롬비기닝',
      ),
    ),
    LiveCompareProduct(
      'https://frombeginning.co.kr/product/detail.html?product_no=22026',
      live: LiveCompareExpected(
        name: '블로우 스퀘어 미니 숄더백',
        price: 63000,
        image:
            'https://ecimg.cafe24img.com/pg1985b57457872046/frombegining/web/product/big/20260807/c1c6e9d86f178bfcc0df7d78cdce917d.gif',
        brand: '프롬비기닝',
      ),
    ),
  ]),
  LiveCompareMall('나이키', [
    LiveCompareProduct(
      'https://www.nike.com/kr/t/나이키-에어-포스-1-07-남성-신발-qdjlTENZ/IH1698-100',
      live: LiveCompareExpected(
        name: "에어 포스 1 '07",
        price: 134100,
        image:
            'https://static.nike.com/a/images/t_default/6a864f6a-d44d-4778-af91-2d24ee5bab06/AIR+FORCE+1+%2707.png',
        brand: '나이키',
      ),
    ),
  ]),
  LiveCompareMall('올리브영', [
    LiveCompareProduct(
      'https://www.oliveyoung.co.kr/store/goods/getGoodsDetail.do?goodsNo=A000000260600',
    ),
    LiveCompareProduct(
      'https://www.oliveyoung.co.kr/store/goods/getGoodsDetail.do?goodsNo=A000000210792',
    ),
    LiveCompareProduct(
      'https://www.oliveyoung.co.kr/store/goods/getGoodsDetail.do?goodsNo=A000000171427',
    ),
  ]),
  LiveCompareMall('퀸잇', [
    LiveCompareProduct(
      'https://web.queenit.kr/product/421b849e05731238976b9f01d96c7e31',
    ),
  ]),
  LiveCompareMall('브랜디', [
    LiveCompareProduct('https://www.brandi.co.kr/products/158997563'),
  ]),
  LiveCompareMall('CJ온스타일', [
    LiveCompareProduct('https://display.cjonstyle.com/p/item/2078847097'),
  ]),
  LiveCompareMall('4910', [
    LiveCompareProduct('https://4910.kr/desktop/goods/64333542'),
  ]),
  LiveCompareMall('SSF샵', [
    LiveCompareProduct('https://www.ssfshop.com/GOOD-ON/GPCX25041604994/good'),
  ]),
  LiveCompareMall('이랜드몰', [
    LiveCompareProduct(
      'https://www.elandmall.co.kr/i/item?itemNo=2607498077&lowerVendNo=LV25019098',
    ),
  ]),
];
