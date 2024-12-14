import 'package:app/screens/add_pre_auction_page.dart';
import 'package:app/services/pre_auction_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _signOut(BuildContext context) async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign out failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FarmBid'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      user?.photoURL != null
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(user!.photoURL!),
                              radius: 30,
                            )
                          : const CircleAvatar(
                              child: Icon(Icons.account_circle, size: 40),
                              radius: 30,
                            ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back,',
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            user?.displayName ?? 'User',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Add Future Harvests Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Future Harvests',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => AddPreAuctionPage()),
                          );
                        },
                        icon: const Icon(Icons.add, color: Colors.green),
                        label: const Text('Add Post',
                            style: TextStyle(color: Colors.green)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: PreAuctionService().getFutureHarvests(),
                    builder: (context, snapshot) {
                      print(
                          'Future Harvests Stream Update: ${snapshot.connectionState}');

                      if (snapshot.hasError) {
                        print('Error in Future Harvests: ${snapshot.error}');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Error loading future harvests'),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {});
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final currentUserId =
                          FirebaseAuth.instance.currentUser?.uid;
                      final docs = snapshot.data?.docs
                              .where(
                                  (doc) => doc.get('sellerId') != currentUserId)
                              .toList() ??
                          [];

                      print(
                          'Processing ${docs.length} future harvest documents');

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('No future harvests posted yet'),
                        );
                      }

                      return Column(
                        children: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          print('Building card for document: ${doc.id}');
                          return _buildFutureHarvestCard(data, doc.id);
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Your Interests Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Interests',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('pre_auction_listings')
                        .where('interestedBuyerIds',
                            arrayContains:
                                FirebaseAuth.instance.currentUser?.uid)
                        .where('isListed', isEqualTo: false)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No interests marked yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return Column(
                        children: snapshot.data!.docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(data['productName']),
                              subtitle: Text(
                                'Expected: ${_formatDate(DateTime.parse(data['expectedHarvestDate']))}',
                              ),
                              trailing: const Icon(Icons.notifications_active),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Your Posts Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Posts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('pre_auction_listings')
                        .where('sellerId',
                            isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .where('isListed', isEqualTo: false)
                        .orderBy('expectedHarvestDate')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return const Center(
                          child: Text('Error loading your posts'),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return Center(
                          child: Column(
                            children: [
                              const Text(
                                'No posts yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddPreAuctionPage(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add New Post'),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return _buildFutureHarvestCard(data, doc.id);
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Featured Categories
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Featured Categories',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<Map<String, int>>(
                    stream: _getCategoryCounts(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final categoryCounts = snapshot.data ??
                          {
                            'Vegetables': 0,
                            'Fruits': 0,
                            'Grains': 0,
                            'Dairy': 0,
                          };

                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        children: categoryCounts.entries.map((entry) {
                          return _buildCategoryCard(
                            entry.key,
                            'assets/${entry.key.toLowerCase()}.png',
                            '${entry.value} items',
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Trending Auctions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trending Auctions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTrendingAuctions(),
                ],
              ),
            ),

            // Tips Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: Colors.green.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'Quick Tips',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Watch trending items for better deals\n'
                        '• Verify your account for instant bidding\n'
                        '• Check seller ratings before bidding',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.green, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String title, String imagePath, String itemCount) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getCategoryIcon(title),
            size: 40,
            color: Colors.green,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            itemCount,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'vegetables':
        return Icons.eco;
      case 'fruits':
        return Icons.apple;
      case 'grains':
        return Icons.grass;
      case 'dairy':
        return Icons.water_drop;
      default:
        return Icons.category;
    }
  }

  Widget _buildTrendingAuctions() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('auction_items')
          .orderBy('currentBid', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Something went wrong');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: (snapshot.data?.docs ?? []).map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.trending_up, color: Colors.green),
                ),
                title: Text(data['name'] ?? 'Unknown Item'),
                subtitle: Text('Current Bid: ₹${data['currentBid']}'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Navigate to auction detail
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildFutureHarvestCard(Map<String, dynamic> data, String docId) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bool isOwner = data['sellerId'] == currentUserId;
    final bool isInterested =
        (data['interestedBuyerIds'] as List<dynamic>).contains(currentUserId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade50,
              child: const Icon(Icons.eco, color: Colors.green),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(data['productName'] ?? 'Unknown Product'),
                ),
                if (isOwner)
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Listing'),
                            content: const Text(
                                'Are you sure you want to delete this listing?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  PreAuctionService()
                                      .deletePreAuctionListing(docId);
                                  Navigator.pop(context);
                                },
                                child: const Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seller: ${data['sellerName']}'),
                Text(
                    'Expected: ${_formatDate(DateTime.parse(data['expectedHarvestDate']))}'),
                Text('Quantity: ${data['estimatedQuantity']} kg'),
                if (data['description']?.isNotEmpty ?? false)
                  Text('Description: ${data['description']}'),
              ],
            ),
            trailing: !isOwner
                ? IconButton(
                    icon: Icon(
                      isInterested ? Icons.favorite : Icons.favorite_border,
                      color: isInterested ? Colors.red : null,
                    ),
                    onPressed: () {
                      final preAuctionService = PreAuctionService();
                      if (isInterested) {
                        preAuctionService.unmarkInterested(
                          docId,
                          currentUserId!,
                        );
                      } else {
                        preAuctionService.markInterested(
                          docId,
                          currentUserId!,
                        );
                      }
                    },
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Stream<Map<String, int>> _getCategoryCounts() {
    return FirebaseFirestore.instance
        .collection('auction_items')
        .snapshots()
        .map((snapshot) {
      Map<String, int> counts = {
        'Vegetables': 0,
        'Fruits': 0,
        'Grains': 0,
        'Dairy': 0,
        'Others': 0,
      };

      for (var doc in snapshot.docs) {
        final category = doc.data()['category'] as String? ?? 'Others';
        counts[category] = (counts[category] ?? 0) + 1;
      }

      return counts;
    });
  }
}
