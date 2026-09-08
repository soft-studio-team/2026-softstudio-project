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

/// 2026-08-18 새로 연 상품 페이지에서 확인한 판매가(첫구매·카드 쿠폰 제외).
/// 엔진 상품명에는 브랜드가 붙을 수 있으므로 live.name 은 화면에 보이는 상품명이다.
const liveCompareMalls = <LiveCompareMall>[
  // 2026-09-07: A트랙(규칙 지정/기계적 추출 트랙, mall-fix-plan-2026-09-07.md 참고) 12개 몰만 유지.
  // B트랙(비전 후보) 카탈로그는 사용자 지시로 삭제함 — 상세 이력은 project docs
  // mall-accuracy-audit-progress-2026-09-07.md 5절/6절 참고.
  LiveCompareMall("무신사", [
    LiveCompareProduct(
      "https://www.musinsa.com/products/4341120",
      live: LiveCompareExpected(
        name: "클래식 반소매 티셔츠 - 블랙 / 801474YB2FT1000",
        price: 105990,
        image:
            "https://image.msscdn.net/images/goods_img/20240819/4341120/4341120_17254134643550_500.jpg",
      ),
    ),
    LiveCompareProduct(
      "https://www.musinsa.com/products/6797005",
      live: LiveCompareExpected(
        name: "Days Comfort Fit Shirt_White",
        price: 80100,
        image:
            "https://image.msscdn.net/images/goods_img/20260707/6797005/6797005_17852305721496_500.jpg",
      ),
    ),
    LiveCompareProduct(
      "https://www.musinsa.com/products/6677115",
      live: LiveCompareExpected(
        name: "소프트 헨리넥 반팔 티셔츠 [브라운]",
        price: 20400,
        image:
            "https://image.msscdn.net/images/goods_img/20260616/6677115/6677115_17852914703616_500.jpg",
      ),
    ),
  ]),
  LiveCompareMall("W컨셉", [
    LiveCompareProduct(
      "https://www.wconcept.co.kr/Product/308678703",
      live: LiveCompareExpected(
        name: "멀티 유즈 슬리브리스 탑 브라운 OU2006",
        price: 39000,
        image:
            "https://product-image.wconcept.co.kr/productimg/image/img9/03/308678703_UI25679.jpg",
        brand: "ouie",
      ),
    ),
    LiveCompareProduct(
      "https://www.wconcept.co.kr/Product/308589275",
      live: LiveCompareExpected(
        name: "Soft Drape T-shirt_3Color",
        price: 88000,
        image:
            "https://product-image.wconcept.co.kr/productimg/image/img9/75/308589275_EP72624.jpg",
        brand: "FLOWOOM",
      ),
    ),
    LiveCompareProduct(
      "https://www.wconcept.co.kr/Product/308629259",
      live: LiveCompareExpected(
        name: "[단독][SET] Wrap Detail T-Shirt & V-Neck Sleeveless Top",
        price: 102000,
        image:
            "https://product-image.wconcept.co.kr/productimg/image/img9/59/308629259_VW44687.jpg",
        brand: "THE RYE",
      ),
    ),
  ]),
  LiveCompareMall("29CM", [
    LiveCompareProduct(
      "https://www.29cm.co.kr/products/3769341",
      live: LiveCompareExpected(
        name: "[꼬민지PICK/29CM 단독] SIOT4182 하이 넥 버튼 블루종_Navy",
        price: 163660,
        image:
            "https://img.29cm.co.kr/item/202602/11f10e4064ca6ebca3c031a646d4f5cd.jpg",
      ),
    ),
    LiveCompareProduct(
      "https://www.29cm.co.kr/products/3423314",
      live: LiveCompareExpected(
        name:
            "[Atelier Edition] W/Two Way Vegan Leather Jacket_2COLOR(WC25-OT09)",
        price: 191670,
        image:
            "https://img.29cm.co.kr/item/202509/11f093803023ba4494a2b7e59c753ef1.jpg",
      ),
    ),
    LiveCompareProduct(
      "https://www.29cm.co.kr/products/3765311",
      live: LiveCompareExpected(
        name: "[10월 02일 예약발송][꼬민지 PICK][14th] faux leather half coat_black",
        price: 175200,
        image:
            "https://img.29cm.co.kr/item/202608/11f199cc75fcdd8885e1f77211683ab4.jpg",
      ),
    ),
  ]),
  LiveCompareMall("유니클로", [
    LiveCompareProduct(
      "https://www.uniqlo.com/kr/ko/products/E488796-000/00?colorDisplayCode=00&sizeDisplayCode=005",
      live: LiveCompareExpected(
        name: "젠더리스 옥스포드오버사이즈셔츠",
        price: 49900,
        image:
            "https://image.uniqlo.com/UQ/ST3/kr/imagesgoods/488796/sub/krgoods_488796_sub14_3x4.jpg",
      ),
    ),
    LiveCompareProduct(
      "https://www.uniqlo.com/kr/ko/products/E488798-000/00?colorDisplayCode=32&sizeDisplayCode=005",
      live: LiveCompareExpected(
        name: "젠더리스 옥스포드오버사이즈셔츠(스트라이프)B",
        price: 49900,
        image:
            "https://image.uniqlo.com/UQ/ST3/kr/imagesgoods/488798/sub/krgoods_488798_sub3_3x4.jpg",
      ),
    ),
    LiveCompareProduct(
      "https://www.uniqlo.com/kr/ko/products/E488797-000/00?colorDisplayCode=54&sizeDisplayCode=005",
      live: LiveCompareExpected(
        name: "젠더리스 옥스포드오버사이즈셔츠(스트라이프)A",
        price: 49900,
        image:
            "https://image.uniqlo.com/UQ/ST3/kr/imagesgoods/488797/sub/krgoods_488797_sub3_3x4.jpg",
      ),
    ),
  ]),
  LiveCompareMall("에이블리", [
    LiveCompareProduct(
      "https://mobile.a-bly.com/goods/75432976",
      live: LiveCompareExpected(
        name: "[하이넥/간절기필수🍂] 톤텔 루즈 사선 지퍼 후드집업",
        price: 25650,
        image:
            "https://imgb.a-bly.com/data/goods/7b7beef563b76b4fa88149111c73b23f.gif",
      ),
    ),
    LiveCompareProduct(
      "https://mobile.a-bly.com/goods/75506878",
      live: LiveCompareExpected(
        name: "[여리코어🪡] made 소피 여리 펀칭 니트 - 4color",
        price: 22780,
        image:
            "https://imgb.a-bly.com/data/goods/1ae2f183f57bb3474c726cf53f09e5e0.gif",
      ),
    ),
    LiveCompareProduct(
      "https://mobile.a-bly.com/goods/28244036",
      live: LiveCompareExpected(
        name: "🏆1위🏆 스킨 레이어 핏 파운데이션",
        price: 26600,
        image: "https://imgb.a-bly.com/data/goods/25557256cc908c7eb4887da1cef5cc5e.gif",
      ),
    ),
  ]),
  LiveCompareMall("지그재그", [
    LiveCompareProduct(
      "https://zigzag.kr/catalog/products/159126270",
      live: LiveCompareExpected(
        name: "[MADE] 로브닝 레이스 브이넥 슬리브리스",
        price: 17500,
        image: "https://cf.product-image.s.zigzag.kr/original/c/15/912/627/159126270-2264955569924090591.jpeg",
      ),
    ),
    LiveCompareProduct(
      "https://zigzag.kr/catalog/products/168362278",
      live: LiveCompareExpected(
        name: "화이트랩스 치아미백기 LED 셀프 자가 치아미백기계 &amp; 치아미백젤 세트 (1인용)",
        price: 179000,
        image:
            "https://cf.product-image.s.zigzag.kr/original/d/2026/2/3/59382_202602031710060884_61349.jpeg",
      ),
    ),
    LiveCompareProduct(
      "https://zigzag.kr/catalog/products/161980550",
      live: LiveCompareExpected(
        name: "💓뷰티위크 특가💓 [조말론] 블랙베리 앤 베이 코롱 100ml (블랙베리향) (+선물포장)",
        price: 191290,
        image:
            "https://cf.product-image.s.zigzag.kr/original/d/2026/7/16/40976_202607161436522871_71643.jpeg",
      ),
    ),
  ]),
  LiveCompareMall("KREAM", [
    LiveCompareProduct(
      "https://kream.co.kr/products/1012767",
      live: LiveCompareExpected(
        name:
            "[KREAM 단독] Thevinylhouse x Bocchi the Rock! Kessoku Star Layered Ls Tee Black",
        price: 75000,
        image:
            "https://kream-phinf.pstatic.net/MjAyNjA3MjFfMTg4/MDAxNzg0NjI1NjU1NjM1.2BI9VXVbcdapWUmRh0WlEwr_hv_5W7N9xFYqHb05Pycg.GPpdMDscTfgzG9PM3uOktT3yV5TjyOibgMklxlCgfnsg.PNG/p_d155324f3a38439dbbfd707b2d447f5f.png",
      ),
    ),
    LiveCompareProduct(
      "https://kream.co.kr/products/1012757",
      live: LiveCompareExpected(
        name:
            "[KREAM 단독] Thevinylhouse x Bocchi the Rock! Kessoku Acrylic Key Ring Pink",
        price: 19000,
        image:
            "https://kream-phinf.pstatic.net/MjAyNjA3MjFfOTUg/MDAxNzg0NjE1NTMwMjk2.BAmLftkmc4G7A3xzGvewt3OmPuR_sRzpIjmUn7hExxYg.8IxWY5b80ELy9K0tNXYS15aisYfYNbEuPg5k6ibXFQAg.PNG/p_b2b51d61d9264fc68948da832b0c0906.png",
      ),
    ),
    LiveCompareProduct(
      "https://kream.co.kr/products/1012784",
      live: LiveCompareExpected(
        name:
            "[KREAM 단독] Thevinylhouse x Bocchi the Rock! Kessoku Friends Tee Black",
        price: 59000,
        image:
            "https://kream-phinf.pstatic.net/MjAyNjA3MjFfMjI3/MDAxNzg0NjE3ODY4Mzg1.UDEeWJY1fUchthKDAaTpRFlDedLp0QZPloakINgb3oAg.XJv6aiPlKmv1s-z6TL5OOoBvQpD_URRpaU45gZYk0mYg.PNG/p_aef519f6b61f43fabb7eda41dac1a1bd.png",
      ),
    ),
  ]),
  LiveCompareMall("나이키", [
    LiveCompareProduct(
      "https://www.nike.com/kr/t/acg-%EB%8F%8C%EB%A1%9C%EB%AF%B8%ED%8B%B0-%EC%BD%94%EB%93%80%EB%A1%9C%EC%9D%B4-%EC%9E%AC%ED%82%B7-6afaYkrC/IM4254-104",
      live: LiveCompareExpected(
        name: "ACG '돌로미티' 코듀로이 재킷",
        price: 189000,
        image:
            "https://static.nike.com/a/images/t_default/u_9ddf04c7-2a9a-4d76-add1-d15af8f0263d,c_scale,fl_relative,w_1.0,h_1.0,fl_layer_apply/02416b55-9304-42b2-95fc-12ff75aada31/AS+U+ACG+DOLOMITI+YUNNAN+CORD.png",
      ),
    ),
    LiveCompareProduct(
      "https://www.nike.com/kr/t/acg-%EB%8F%8C%EB%A1%9C%EB%AF%B8%ED%8B%B0-%EC%BD%94%EB%93%80%EB%A1%9C%EC%9D%B4-%EC%87%BC%EC%B8%A0-wqfRDNM2/IM4222-104",
      live: LiveCompareExpected(
        name: "ACG '돌로미티' 코듀로이 쇼츠",
        price: 115000,
        image:
            "https://static.nike.com/a/images/t_default/u_9ddf04c7-2a9a-4d76-add1-d15af8f0263d,c_scale,fl_relative,w_1.0,h_1.0,fl_layer_apply/1ca8ce9e-fa71-4dd0-a7ec-722906e781da/AS+U+ACG+DOLOMITI+YUNNAN+CRD+S.png",
      ),
    ),
    LiveCompareProduct(
      "https://www.nike.com/kr/t/%EB%82%98%EC%9D%B4%ED%82%A4-%ED%8E%98%EA%B0%80%EC%88%98%EC%8A%A4-42-%EC%97%AC%EC%84%B1-%EB%A1%9C%EB%93%9C-%EB%9F%AC%EB%8B%9D%ED%99%94-J3FQiYIc/IB1881-106",
      live: LiveCompareExpected(
        name: "나이키 페가수스 42 여성 로드 러닝화",
        price: 169000,
        image:
            "https://static.nike.com/a/images/t_default/u_9ddf04c7-2a9a-4d76-add1-d15af8f0263d,c_scale,fl_relative,w_1.0,h_1.0,fl_layer_apply/522aebea-2c93-411d-a8ef-cad78715368a/W+NIKE+AIR+ZOOM+PEGASUS+42.png",
      ),
    ),
  ]),
  LiveCompareMall("퀸잇", [
    LiveCompareProduct(
      "https://web.queenit.kr/product/421b849e05731238976b9f01d96c7e31",
      live: LiveCompareExpected(
        name: "[M,L 사이즈/벨트세트]반팔 데님 원피스(하객룩, 하객원피스)",
        price: 29900,
        image:
            "https://image.queenit.kr/product/asset/v1/upload/04120430d08047c38524a66065b43ca2.jpg",
      ),
    ),
    LiveCompareProduct(
      "https://web.queenit.kr/product/360e9e7089a6346d2e9b5de2b2d8e121",
      live: LiveCompareExpected(
        name: "[비버리힐스폴로클럽]여성 케이블 라운드 니트 폴로 가디건 TK001 _A",
        price: 33900,
        image:
            "https://imgs.kshop.co.kr/d2/emc/goods/openmarket/queenit/5250535/5250535_20250421165441.png",
      ),
    ),
    LiveCompareProduct(
      "https://web.queenit.kr/product/b52c66c75291c8ef4d9f136282cac90c",
      live: LiveCompareExpected(
        name: "모에나 레이어 가디건",
        price: 35900,
        image:
            "https://irisccc.cafe24.com/web/upload/NNEditor/20260316/8f6ebe26042b013dbd95d700f5d3abfe.jpg",
      ),
    ),
  ]),
  LiveCompareMall("4910", [
    LiveCompareProduct(
      "https://4910.kr/goods/44678113",
      live: LiveCompareExpected(
        name: "그루브스텝 [2PACK] 1+1 랩스타미니 라운드 반팔 티셔츠 S0217 - 4910 | 사고 싶은 스타일의 발견",
        price: 34800,
        image:
            "https://d3ha2047wt6x28.cloudfront.net/FA45r5mdpZY/pr:GOODS_DETAIL/czM6Ly9hYmx5LWltYWdlLWxlZ2FjeS9kYXRhL2dvb2RzLzIwMjYwNTIyXzE3Nzk0NTI1Mjg0MTgwOTdtLnBuZw",
      ),
    ),
    LiveCompareProduct(
      "https://4910.kr/goods/71195041",
      live: LiveCompareExpected(
        name: "모즈모즈 [단독1+1] 무지 배색 롤업 반팔티셔츠 - 4910 | 사고 싶은 스타일의 발견",
        price: 47200,
        image:
            "https://d3ha2047wt6x28.cloudfront.net/YL2tLW-EPb0/pr:GOODS_DETAIL/czM6Ly9hYmx5LWltYWdlLWxlZ2FjeS9kYXRhL2dvb2RzLzIwMjYwNjE4XzE3ODE3NjU3OTQ1MzAyMDJtLmpwZw",
      ),
    ),
    LiveCompareProduct(
      "https://4910.kr/goods/3954236",
      live: LiveCompareExpected(
        name: "플루크 캠퍼밴 투어 피그먼트 반팔티셔츠 FST710 / 4color W - 4910 | 사고 싶은 스타일의 발견",
        price: 24800,
        image:
            "https://d3ha2047wt6x28.cloudfront.net/z6T_-U60HFk/pr:GOODS_DETAIL/czM6Ly9hYmx5LWltYWdlLWxlZ2FjeS9kYXRhL2dvb2RzLzIwMjMwODA5XzE2OTE1NjQwMDAwMzI1MTZtLmpwZw",
      ),
    ),
  ]),
  LiveCompareMall("SSF샵", [
    LiveCompareProduct(
      "https://www.ssfshop.com/GOOD-ON/GPCX21040888339/good",
      live: LiveCompareExpected(
        name: "굿온 피그먼트 다잉 베이스볼 티셔츠 - 네츄럴",
        price: 70400,
        image:
            "https://img.ssfshop.com/cmd/LB_750x1000/src/https://img.ssfshop.com/goods/ORBR/21/04/08/GPCX21040888339_0_THNAIL_ORGINL_20240503185548877.jpg",
      ),
    ),
    LiveCompareProduct(
      "https://www.ssfshop.com/GOOD-ON/GPCX21031513266/good",
      live: LiveCompareExpected(
        name: "굿온 피그먼트 다잉 베이스볼 티셔츠 - 바나나",
        price: 70400,
        image:
            "https://img.ssfshop.com/cmd/LB_750x1000/src/https://img.ssfshop.com/goods/ORBR/21/03/15/GPCX21031513266_0_ORGINL_20220708125043755.jpg",
      ),
    ),
    LiveCompareProduct(
      "https://www.ssfshop.com/GOOD-ON/GPCX22072270530/good",
      live: LiveCompareExpected(
        name: "굿온 피그먼트 다잉 베이스볼 티셔츠 - 세이지",
        price: 70400,
        image:
            "https://img.ssfshop.com/cmd/LB_750x1000/src/https://img.ssfshop.com/goods/ORBR/22/07/22/GPCX22072270530_0_ORGINL_20230428144836311.jpg",
      ),
    ),
  ]),
  LiveCompareMall("포스티", [
    // 케이스 A: 판매가(10,900) + 최초판매가(59,600) + 쿠폰할인가(9,810, 제외) 공존.
    LiveCompareProduct(
      "https://posty.kr/products/169042232",
      live: LiveCompareExpected(
        name: "[1+1] 바겐슈타이거  플래티넘 실리콘 멜로우 와이드 뒤집개",
        price: 10900,
        image:
            "https://cf.product-image.s.zigzag.kr/original/d/2026/3/17/58450_202603171149510230_29243.jpeg?width=720&height=720&quality=80&format=jpeg",
      ),
    ),
    // 케이스 B: 판매가 없음 — 최초판매가(35,900)가 곧 무조건가. 쿠폰할인가(32,310)는 제외.
    LiveCompareProduct(
      "https://posty.kr/products/171822906",
      live: LiveCompareExpected(
        name: "[쉬즈프리티] 아모스빈티지스웨이드자켓",
        price: 35900,
        image:
            "https://cf.product-image.s.zigzag.kr/original/d/2026/9/6/62697_202609061801101378_79249.jpeg?width=720&height=720&quality=80&format=jpeg",
      ),
    ),
    // 케이스 C: 판매가(31,900) + 최초판매가(239,000), 쿠폰할인가 없음.
    LiveCompareProduct(
      "https://posty.kr/products/170139765",
      live: LiveCompareExpected(
        name: "[예쎄] 셔링 주름 퍼프 소매 롱 원피스(S6MOP064A)",
        price: 31900,
        image:
            "https://cf.product-image.s.zigzag.kr/original/d/2026/6/22/27674_202606221018040984_36315.jpeg?width=720&height=720&quality=80&format=jpeg",
      ),
    ),
  ]),
];
